// Copyright 2018 Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0

#![deny(missing_docs)]
//! Crate that implements Firecracker specific functionality as far as logging and metrics
//! collecting.

#[macro_use(concat_string)]
extern crate concat_string;

/// Used to manage libs from a description file for unikraft
pub mod binary;
/// Used to manage custom loader for unikraft
pub mod uk_loader;
