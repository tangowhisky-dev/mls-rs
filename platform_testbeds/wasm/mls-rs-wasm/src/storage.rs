// Durable MLS state storage backed by IndexedDB with AES-256-GCM
// value-level encryption — the same model Wire's CoreCrypto keystore
// uses on the web.
//
// Layout (database `mls-rs-{name}`, version 1):
//   object store "groups"       key: hex(group_id)            value: ciphertext
//   object store "epochs"       key: "hex(group_id):epoch_id" value: ciphertext
//   object store "key_packages" key: hex(package id)          value: ciphertext
//
// Every stored value is `nonce(12B) || AES-256-GCM(plaintext, aad=key)`
// under an application-supplied 32-byte key. Row keys stay plaintext
// (they are needed for lookup and double as the AAD, like Wire).
//
// IndexedDB is asynchronous while the mls-rs storage traits are
// synchronous in the default build. This module therefore keeps a
// hydrated in-memory working copy (reads are served synchronously)
// and performs write-behind: every `write`/`insert`/`delete` updates
// memory and immediately spawns an IndexedDB transaction covering the
// whole batch atomically. `WasmClient.flushStorage()` awaits all
// pending writes and surfaces write errors — call it before the page
// unloads. In `mls_build_async` builds the writes are awaited inside
// the storage call instead, so durability is per-operation and errors
// propagate directly.

use std::collections::{HashMap, VecDeque};
use std::sync::{Arc, Mutex};

use aes_gcm::{
    aead::{Aead, Payload},
    Aes256Gcm, KeyInit,
};
use futures_channel::oneshot;
use idb::{Database, DatabaseEvent, Factory, ObjectStoreParams, Query, TransactionMode};
use mls_rs::storage_provider::in_memory::{InMemoryGroupStateStorage, InMemoryKeyPackageStorage};
use mls_rs_codec::{MlsDecode, MlsEncode};
use mls_rs_core::{
    error::IntoAnyError,
    group::{EpochRecord, GroupState, GroupStateStorage},
    key_package::{KeyPackageData, KeyPackageStorage},
};
use wasm_bindgen::JsError;
use zeroize::Zeroizing;

const STORE_GROUPS: &str = "groups";
const STORE_EPOCHS: &str = "epochs";
const STORE_KEY_PACKAGES: &str = "key_packages";
const DB_VERSION: u32 = 1;

/// Mirrors `DEFAULT_EPOCH_RETENTION_LIMIT` in mls-rs' in-memory storage
/// (`pub(crate)`, so redeclared here).
const MAX_EPOCH_RETENTION: usize = 3;

fn hex(bytes: &[u8]) -> String {
    const DIGITS: &[u8; 16] = b"0123456789abcdef";
    let mut s = String::with_capacity(bytes.len() * 2);
    for b in bytes {
        s.push(DIGITS[(b >> 4) as usize] as char);
        s.push(DIGITS[(b & 0xf) as usize] as char);
    }
    s
}

fn hex_decode(s: &str) -> Result<Vec<u8>, JsError> {
    if s.len() % 2 != 0 {
        return Err(JsError::new("corrupt hex key in storage"));
    }
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16))
        .collect::<Result<_, _>>()
        .map_err(|e| JsError::new(&format!("corrupt hex key in storage: {e:?}")))
}

fn epoch_key(group_id: &[u8], epoch_id: u64) -> String {
    format!("{}:{epoch_id}", hex(group_id))
}

fn parse_epoch_key(key: &str) -> Option<(Vec<u8>, u64)> {
    let (gid_hex, eid) = key.rsplit_once(':')?;
    Some((hex_decode(gid_hex).ok()?, eid.parse().ok()?))
}

fn js_err<E: std::fmt::Debug>(e: E) -> JsError {
    JsError::new(&format!("{e:?}"))
}

#[derive(Debug, thiserror::Error)]
#[error("persistent storage error: {0}")]
pub struct StorageError(String);

impl From<String> for StorageError {
    fn from(e: String) -> Self {
        StorageError(e)
    }
}

impl IntoAnyError for StorageError {
    fn into_dyn_error(self) -> Result<Box<dyn std::error::Error + Send + Sync>, Self> {
        Ok(self.into())
    }
}

fn err_string<E: std::fmt::Debug>(e: E) -> String {
    format!("{e:?}")
}

/// The in-memory stores are infallible (`Error = Infallible`); this
/// converts that absence of failure into our error type.
fn never(e: std::convert::Infallible) -> StorageError {
    match e {}
}

/// One IndexedDB mutation inside a batched transaction.
enum StoreOp {
    Put { store: &'static str, key: String },
    Delete { store: &'static str, key: String },
}

fn put(store: &'static str, key: String, value: Vec<u8>) -> (StoreOp, Vec<u8>) {
    (StoreOp::Put { store, key }, value)
}

fn del(store: &'static str, key: String) -> (StoreOp, Vec<u8>) {
    (StoreOp::Delete { store, key }, Vec::new())
}

/// Handle to the open IndexedDB database plus the encryption key.
/// Shared by all storage impls of one client and by `WasmClient` for
/// `flushStorage` / `deletePersistentStorage`.
pub(crate) struct IdbBackend {
    db: Database,
    cipher: Aes256Gcm,
    /// Receivers for in-flight write-behind transactions (sync builds).
    pending: Mutex<Vec<oneshot::Receiver<Result<(), String>>>>,
    /// First write-behind failure, surfaced by `flush`.
    last_error: Mutex<Option<String>>,
}

// SAFETY: `idb::Database` internally holds `!Send`/`!Sync` event
// callbacks. This module is only compiled for
// `wasm32-unknown-unknown`, which is single-threaded — no value can
// actually cross a thread boundary — so Send/Sync are sound here.
// This build is also incompatible with `atomics` (wasm-bindgen
// threads), which would invalidate the assumption.
unsafe impl Send for IdbBackend {}
unsafe impl Sync for IdbBackend {}

impl IdbBackend {
    /// Open (or create) the IndexedDB database `mls-rs-{name}`.
    async fn open(name: &str, key: &[u8]) -> Result<Arc<Self>, JsError> {
        let cipher = Aes256Gcm::new_from_slice(key)
            .map_err(|_| JsError::new("storage key must be 32 bytes"))?;

        let mut request = Factory::new()
            .map_err(|e| JsError::new(&format!("IndexedDB unavailable: {e:?}")))?
            .open(&format!("mls-rs-{name}"), Some(DB_VERSION))
            .map_err(|e| JsError::new(&format!("IndexedDB open failed: {e:?}")))?;

        request.on_upgrade_needed(|event| {
            let db = event.database().expect("upgrade event without db");
            for store in [STORE_GROUPS, STORE_EPOCHS, STORE_KEY_PACKAGES] {
                db.create_object_store(store, ObjectStoreParams::new())
                    .expect("create object store");
            }
        });

        let db = request
            .await
            .map_err(|e| JsError::new(&format!("IndexedDB open failed: {e:?}")))?;

        Ok(Arc::new(Self {
            db,
            cipher,
            pending: Mutex::new(Vec::new()),
            last_error: Mutex::new(None),
        }))
    }

    /// Delete the whole `mls-rs-{name}` IndexedDB database.
    async fn delete_database(name: &str) -> Result<(), JsError> {
        Factory::new()
            .map_err(|e| JsError::new(&format!("IndexedDB unavailable: {e:?}")))?
            .delete(&format!("mls-rs-{name}"))
            .map_err(|e| JsError::new(&format!("IndexedDB delete failed: {e:?}")))?
            .await
            .map_err(|e| JsError::new(&format!("IndexedDB delete failed: {e:?}")))
    }

    fn encrypt(&self, aad: &str, plaintext: &[u8]) -> Result<Vec<u8>, StorageError> {
        let mut nonce_bytes = [0u8; 12];
        getrandom::getrandom(&mut nonce_bytes).map_err(|e| StorageError(err_string(e)))?;
        let ct = self
            .cipher
            .encrypt(
                aes_gcm::Nonce::from_slice(&nonce_bytes),
                Payload {
                    msg: plaintext,
                    aad: aad.as_bytes(),
                },
            )
            .map_err(|_| StorageError("AES-256-GCM encrypt failed".into()))?;
        let mut out = Vec::with_capacity(12 + ct.len());
        out.extend_from_slice(&nonce_bytes);
        out.extend_from_slice(&ct);
        Ok(out)
    }

    fn decrypt(&self, aad: &str, blob: &[u8]) -> Result<Vec<u8>, StorageError> {
        if blob.len() < 12 {
            return Err(StorageError("stored record too short".into()));
        }
        let (nonce, ct) = blob.split_at(12);
        self.cipher
            .decrypt(
                aes_gcm::Nonce::from_slice(nonce),
                Payload {
                    msg: ct,
                    aad: aad.as_bytes(),
                },
            )
            .map_err(|_| {
                StorageError("decrypt failed (wrong storage key or corrupted record)".into())
            })
    }

    async fn all_entries(&self, store: &str) -> Result<Vec<(String, Vec<u8>)>, String> {
        let tx = self
            .db
            .transaction(&[store], TransactionMode::ReadOnly)
            .map_err(err_string)?;
        let object_store = tx.object_store(store).map_err(err_string)?;
        let keys = object_store
            .get_all_keys(None, None)
            .map_err(err_string)?
            .await
            .map_err(err_string)?;
        let values = object_store
            .get_all(None, None)
            .map_err(err_string)?
            .await
            .map_err(err_string)?;
        tx.await.map_err(err_string)?;

        Ok(keys
            .into_iter()
            .zip(values)
            .filter_map(|(k, v)| {
                k.as_string()
                    .map(|k| (k, js_sys::Uint8Array::new(&v).to_vec()))
            })
            .collect())
    }

    /// Apply a batch of mutations inside one transaction — the
    /// atomicity `GroupStateStorage::write` requires.
    async fn apply(&self, ops: Vec<(StoreOp, Vec<u8>)>) -> Result<(), String> {
        let tx = self
            .db
            .transaction(
                &[STORE_GROUPS, STORE_EPOCHS, STORE_KEY_PACKAGES],
                TransactionMode::ReadWrite,
            )
            .map_err(err_string)?;

        for (op, value) in ops {
            let (store_name, key) = match &op {
                StoreOp::Put { store, key } | StoreOp::Delete { store, key } => (*store, key),
            };
            let store = tx.object_store(store_name).map_err(err_string)?;
            match op {
                StoreOp::Put { .. } => {
                    store
                        .put(
                            &js_sys::Uint8Array::from(value.as_slice()),
                            Some(&wasm_bindgen::JsValue::from_str(&key)),
                        )
                        .map_err(err_string)?
                        .await
                        .map_err(err_string)?;
                }
                StoreOp::Delete { .. } => {
                    store
                        .delete(Query::from(wasm_bindgen::JsValue::from_str(&key)))
                        .map_err(err_string)?
                        .await
                        .map_err(err_string)?;
                }
            }
        }

        tx.commit()
            .map_err(err_string)?
            .await
            .map_err(err_string)
            .map(|_| ())
    }

    /// Sync-build write path: spawn the transaction now and remember a
    /// receiver `flush` can await. The first failure is captured for
    /// `flush` to surface.
    #[cfg(not(mls_build_async))]
    fn spawn_write(self: &Arc<Self>, ops: Vec<(StoreOp, Vec<u8>)>) {
        let (tx, rx) = oneshot::channel();
        self.pending.lock().unwrap().push(rx);
        let backend = Arc::clone(self);
        wasm_bindgen_futures::spawn_local(async move {
            let res = backend.apply(ops).await;
            if let Err(e) = &res {
                let mut last = backend.last_error.lock().unwrap();
                if last.is_none() {
                    *last = Some(e.clone());
                }
            }
            let _ = tx.send(res);
        });
    }

    /// Async-build write path: awaited inside the storage call so
    /// durability is per-operation and errors propagate.
    #[cfg(mls_build_async)]
    async fn write_through(
        self: &Arc<Self>,
        ops: Vec<(StoreOp, Vec<u8>)>,
    ) -> Result<(), StorageError> {
        // `apply` awaits an `idb` transaction object, which is `!Send`.
        // `SendWrapper` keeps the storage-trait future `Send`; polling a
        // `SendWrapper` from another thread panics, which cannot happen
        // on single-threaded `wasm32-unknown-unknown`.
        send_wrapper::SendWrapper::new(self.apply(ops))
            .await
            .map_err(StorageError)
    }

    /// Close the IndexedDB connection. Pending write-behind
    /// transactions keep running to completion — `close` only blocks
    /// new ones, matching `IDBDatabase.close()` semantics.
    pub(crate) fn close(&self) {
        self.db.close();
    }

    /// Await every queued write-behind transaction; surfaces the first
    /// write error.
    pub(crate) async fn flush(&self) -> Result<(), JsError> {
        loop {
            let rx = self.pending.lock().unwrap().pop();
            match rx {
                Some(rx) => rx
                    .await
                    .map_err(|_| JsError::new("storage task dropped"))?
                    .map_err(|e| JsError::new(&e))?,
                None => break,
            }
        }
        if let Some(e) = self.last_error.lock().unwrap().take() {
            return Err(JsError::new(&e));
        }
        Ok(())
    }
}

/// Group-state storage: hydrated in-memory copy + write-behind (sync
/// builds) or awaited write-through (async builds) to IndexedDB.
/// With `backend: None` it degrades to plain in-memory storage.
#[derive(Clone)]
pub struct IdbGroupStateStorage {
    mem: InMemoryGroupStateStorage,
    backend: Option<Arc<IdbBackend>>,
    /// Live epoch ids per group so trimmed epochs are deleted from
    /// IndexedDB exactly like the in-memory store drops them.
    epoch_ids: Arc<Mutex<HashMap<Vec<u8>, VecDeque<u64>>>>,
}

impl IdbGroupStateStorage {
    /// In-memory only (no persistence) — used by `WasmClient::new`.
    pub fn in_memory() -> Self {
        Self {
            mem: InMemoryGroupStateStorage::new(),
            backend: None,
            epoch_ids: Default::default(),
        }
    }

    async fn hydrate(backend: &Arc<IdbBackend>) -> Result<Self, JsError> {
        let mut mem = InMemoryGroupStateStorage::new();
        let epoch_ids: Arc<Mutex<HashMap<Vec<u8>, VecDeque<u64>>>> = Default::default();

        let mut epochs: HashMap<Vec<u8>, Vec<(u64, Vec<u8>)>> = HashMap::new();
        for (key, blob) in backend.all_entries(STORE_EPOCHS).await.map_err(js_err)? {
            let (gid, eid) = parse_epoch_key(&key)
                .ok_or_else(|| JsError::new("corrupt epoch key in storage"))?;
            let data = backend.decrypt(&key, &blob).map_err(js_err)?;
            epochs.entry(gid).or_default().push((eid, data));
        }

        for (key, blob) in backend.all_entries(STORE_GROUPS).await.map_err(js_err)? {
            let gid = hex_decode(&key)?;
            let data = backend.decrypt(&key, &blob).map_err(js_err)?;
            let group_epochs: Vec<EpochRecord> = epochs
                .remove(&gid)
                .unwrap_or_default()
                .into_iter()
                .map(|(id, data)| EpochRecord::new(id, data.into()))
                .collect();
            epoch_ids
                .lock()
                .unwrap()
                .insert(gid.clone(), group_epochs.iter().map(|e| e.id).collect());
            // The in-memory store is infallible.
            maybe_await!(mem.write(
                GroupState {
                    id: gid,
                    data: Zeroizing::new(data),
                },
                group_epochs,
                Vec::new(),
            ))
            .map_err(|e| -> JsError { match e {} })?;
        }

        Ok(Self {
            mem,
            backend: Some(Arc::clone(backend)),
            epoch_ids,
        })
    }

    /// Compute the write-behind op list: puts for state+epochs plus
    /// deletes for epochs the in-memory store just trimmed.
    fn plan_write(
        &self,
        backend: &IdbBackend,
        state: &GroupState,
        inserts: &[EpochRecord],
        updates: &[EpochRecord],
    ) -> Result<Vec<(StoreOp, Vec<u8>)>, StorageError> {
        let mut ops = Vec::new();
        let gid_key = hex(&state.id);
        ops.push(put(
            STORE_GROUPS,
            gid_key.clone(),
            backend.encrypt(&gid_key, &state.data)?,
        ));

        let mut trimmed = Vec::new();
        if !inserts.is_empty() {
            let mut ids = self.epoch_ids.lock().unwrap();
            let list = ids.entry(state.id.clone()).or_default();
            for e in inserts {
                list.push_back(e.id);
            }
            while list.len() > MAX_EPOCH_RETENTION {
                if let Some(old) = list.pop_front() {
                    trimmed.push(old);
                }
            }
        }
        for e in inserts.iter().chain(updates) {
            let key = epoch_key(&state.id, e.id);
            ops.push(put(
                STORE_EPOCHS,
                key.clone(),
                backend.encrypt(&key, &e.data)?,
            ));
        }
        for id in trimmed {
            ops.push(del(STORE_EPOCHS, epoch_key(&state.id, id)));
        }
        Ok(ops)
    }
}

#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
impl GroupStateStorage for IdbGroupStateStorage {
    type Error = StorageError;

    async fn state(&self, group_id: &[u8]) -> Result<Option<Zeroizing<Vec<u8>>>, Self::Error> {
        maybe_await!(self.mem.state(group_id)).map_err(never)
    }

    async fn epoch(
        &self,
        group_id: &[u8],
        epoch_id: u64,
    ) -> Result<Option<Zeroizing<Vec<u8>>>, Self::Error> {
        maybe_await!(self.mem.epoch(group_id, epoch_id)).map_err(never)
    }

    async fn max_epoch_id(&self, group_id: &[u8]) -> Result<Option<u64>, Self::Error> {
        maybe_await!(self.mem.max_epoch_id(group_id)).map_err(never)
    }

    async fn write(
        &mut self,
        state: GroupState,
        epoch_inserts: Vec<EpochRecord>,
        epoch_updates: Vec<EpochRecord>,
    ) -> Result<(), Self::Error> {
        let ops = self
            .backend
            .as_ref()
            .map(|b| self.plan_write(b, &state, &epoch_inserts, &epoch_updates))
            .transpose()?;

        maybe_await!(self.mem.write(state, epoch_inserts, epoch_updates)).map_err(never)?;

        if let (Some(backend), Some(ops)) = (self.backend.clone(), ops) {
            #[cfg(mls_build_async)]
            backend.write_through(ops).await?;
            #[cfg(not(mls_build_async))]
            backend.spawn_write(ops);
        }
        Ok(())
    }
}

/// Key-package (HPKE init key) storage with the same model as
/// [`IdbGroupStateStorage`]. With `backend: None` it is in-memory only.
#[derive(Clone)]
pub struct IdbKeyPackageStorage {
    mem: InMemoryKeyPackageStorage,
    backend: Option<Arc<IdbBackend>>,
}

impl IdbKeyPackageStorage {
    pub fn in_memory() -> Self {
        Self {
            mem: InMemoryKeyPackageStorage::new(),
            backend: None,
        }
    }

    async fn hydrate(backend: &Arc<IdbBackend>) -> Result<Self, JsError> {
        let mem = InMemoryKeyPackageStorage::new();
        for (key, blob) in backend
            .all_entries(STORE_KEY_PACKAGES)
            .await
            .map_err(js_err)?
        {
            let id = hex_decode(&key)?;
            let data = backend.decrypt(&key, &blob).map_err(js_err)?;
            let pkg = KeyPackageData::mls_decode(&mut data.as_slice()).map_err(js_err)?;
            mem.insert(id, pkg);
        }
        Ok(Self {
            mem,
            backend: Some(Arc::clone(backend)),
        })
    }
}

#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
impl KeyPackageStorage for IdbKeyPackageStorage {
    type Error = StorageError;

    async fn delete(&mut self, id: &[u8]) -> Result<(), Self::Error> {
        self.mem.delete(id);
        if let Some(backend) = &self.backend {
            let ops = vec![del(STORE_KEY_PACKAGES, hex(id))];
            #[cfg(mls_build_async)]
            backend.write_through(ops).await?;
            #[cfg(not(mls_build_async))]
            backend.spawn_write(ops);
        }
        Ok(())
    }

    async fn insert(&mut self, id: Vec<u8>, pkg: KeyPackageData) -> Result<(), Self::Error> {
        self.mem.insert(id.clone(), pkg.clone());
        if let Some(backend) = &self.backend {
            let encoded = pkg
                .mls_encode_to_vec()
                .map_err(|e| StorageError(err_string(e)))?;
            let key = hex(&id);
            let blob = backend.encrypt(&key, &encoded)?;
            let ops = vec![put(STORE_KEY_PACKAGES, key, blob)];
            #[cfg(mls_build_async)]
            backend.write_through(ops).await?;
            #[cfg(not(mls_build_async))]
            backend.spawn_write(ops);
        }
        Ok(())
    }

    async fn get(&self, id: &[u8]) -> Result<Option<KeyPackageData>, Self::Error> {
        Ok(self.mem.get(id))
    }
}

/// Construct the hydrated persistent stores for one database.
pub(crate) async fn open_stores(
    name: &str,
    key: &[u8],
) -> Result<(Arc<IdbBackend>, IdbGroupStateStorage, IdbKeyPackageStorage), JsError> {
    let backend = IdbBackend::open(name, key).await?;
    // A hydrate failure (wrong key, corrupt record) must not leak the
    // open connection — `idb::Database` has no Drop.
    let groups = match IdbGroupStateStorage::hydrate(&backend).await {
        Ok(groups) => groups,
        Err(e) => {
            backend.close();
            return Err(e);
        }
    };
    let key_packages = match IdbKeyPackageStorage::hydrate(&backend).await {
        Ok(key_packages) => key_packages,
        Err(e) => {
            backend.close();
            return Err(e);
        }
    };
    Ok((backend, groups, key_packages))
}

pub(crate) async fn delete_database(name: &str) -> Result<(), JsError> {
    IdbBackend::delete_database(name).await
}
