// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// Copyright by contributors to this project.
// SPDX-License-Identifier: (Apache-2.0 OR MIT)

use mls_rs::error::IntoAnyError;
use mls_rs_core::key_package::KeyPackageData;
use mls_rs_core::mls_rs_codec::{MlsDecode, MlsEncode};
use std::fmt::Debug;
use std::sync::Arc;
#[cfg(not(mls_build_async))]
use std::sync::Mutex;
#[cfg(mls_build_async)]
use tokio::sync::Mutex;

use crate::Error;

/// Storage for key package init secrets.
///
/// `pkg` values are [`KeyPackageData`] serialized with MLS-Codec. They
/// contain HPKE secret key material and MUST be stored encrypted
/// (e.g. in the SQLCipher database alongside group state).
///
/// See [`mls_rs_core::key_package::KeyPackageStorage`].
///
/// # Warning
///
/// Without a persistent implementation, key packages generated before
/// an app restart can no longer be used to join a group: a welcome
/// addressed to them fails with "key package not found".
#[cfg_attr(mls_build_async, uniffi::export(with_foreign))]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(not(mls_build_async), uniffi::export(with_foreign))]
pub trait KeyPackageStorage: Send + Sync + Debug {
    /// Store serialized [`KeyPackageData`] under `id`.
    async fn insert(&self, id: Vec<u8>, pkg: Vec<u8>) -> Result<(), Error>;
    /// Retrieve serialized [`KeyPackageData`] by `id`; `None` when
    /// absent.
    async fn get(&self, id: Vec<u8>) -> Result<Option<Vec<u8>>, Error>;
    /// Delete the entry for `id` (called after the key package was
    /// consumed to join a group). Implementations should securely
    /// erase the secret material.
    async fn delete(&self, id: Vec<u8>) -> Result<(), Error>;
}

/// Adapt a mls-rs `KeyPackageStorage` implementation to the FFI
/// `KeyPackageStorage` trait (used for the default in-memory config).
#[derive(Debug)]
pub(crate) struct KeyPackageStorageAdapter<S>(Mutex<S>);

impl<S> KeyPackageStorageAdapter<S> {
    pub fn new(key_package_storage: S) -> KeyPackageStorageAdapter<S> {
        Self(Mutex::new(key_package_storage))
    }

    #[cfg(not(mls_build_async))]
    fn inner(&self) -> std::sync::MutexGuard<'_, S> {
        self.0.lock().unwrap()
    }

    #[cfg(mls_build_async)]
    async fn inner(&self) -> tokio::sync::MutexGuard<'_, S> {
        self.0.lock().await
    }
}

#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
impl<S, Err> KeyPackageStorage for KeyPackageStorageAdapter<S>
where
    S: mls_rs_core::key_package::KeyPackageStorage<Error = Err> + Debug,
    Err: IntoAnyError,
{
    async fn insert(&self, id: Vec<u8>, pkg: Vec<u8>) -> Result<(), Error> {
        let mut slice = &pkg[..];
        let data = KeyPackageData::mls_decode(&mut slice).map_err(|err| Error::AnyError {
            inner: err.into_any_error(),
        })?;
        self.inner()
            .await
            .insert(id, data)
            .await
            .map_err(|err| err.into_any_error().into())
    }

    async fn get(&self, id: Vec<u8>) -> Result<Option<Vec<u8>>, Error> {
        self.inner()
            .await
            .get(&id)
            .await
            .map_err(|err| err.into_any_error())?
            .map(|data| {
                data.mls_encode_to_vec().map_err(|err| Error::AnyError {
                    inner: err.into_any_error(),
                })
            })
            .transpose()
    }

    async fn delete(&self, id: Vec<u8>) -> Result<(), Error> {
        self.inner()
            .await
            .delete(&id)
            .await
            .map_err(|err| err.into_any_error().into())
    }
}

/// Adapt the FFI `KeyPackageStorage` trait object to the mls-rs
/// `KeyPackageStorage` trait expected by the client builder.
#[derive(Debug, Clone)]
pub struct ClientKeyPackageStorage(Arc<dyn KeyPackageStorage>);

impl From<Arc<dyn KeyPackageStorage>> for ClientKeyPackageStorage {
    fn from(value: Arc<dyn KeyPackageStorage>) -> Self {
        Self(value)
    }
}

#[cfg_attr(not(mls_build_async), maybe_async::must_be_sync)]
#[cfg_attr(mls_build_async, maybe_async::must_be_async)]
impl mls_rs_core::key_package::KeyPackageStorage for ClientKeyPackageStorage {
    type Error = Error;

    async fn delete(&mut self, id: &[u8]) -> Result<(), Self::Error> {
        self.0.delete(id.to_vec()).await
    }

    async fn insert(&mut self, id: Vec<u8>, pkg: KeyPackageData) -> Result<(), Self::Error> {
        let bytes = pkg.mls_encode_to_vec().map_err(|err| Error::AnyError {
            inner: err.into_any_error(),
        })?;
        self.0.insert(id, bytes).await
    }

    async fn get(&self, id: &[u8]) -> Result<Option<KeyPackageData>, Self::Error> {
        self.0
            .get(id.to_vec())
            .await?
            .map(|bytes| {
                let mut slice = &bytes[..];
                KeyPackageData::mls_decode(&mut slice).map_err(|err| Error::AnyError {
                    inner: err.into_any_error(),
                })
            })
            .transpose()
    }
}
