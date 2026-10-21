//! Attribute macros used by rustlibs.

use proc_macro::TokenStream;
use quote::quote;
use syn::{parse_macro_input, Block, ItemFn};

/// Use this instead of `#[byondapi::bind]` for every function BYOND calls.
///
/// It does the same thing, but a panic inside the function becomes a BYOND runtime error.
/// Without it the panic unwinds into BYOND, and that takes down DreamDaemon.
#[proc_macro_attribute]
pub fn bind(args: TokenStream, input: TokenStream) -> TokenStream {
    let args = proc_macro2::TokenStream::from(args);
    let mut function = parse_macro_input!(input as ItemFn);

    // Run the original body inside crate::logging::catch_panic().
    let output = &function.sig.output;
    let body = &function.block;
    let wrapped: Block = syn::parse_quote! {
        {
            crate::logging::catch_panic(move || #output #body)
        }
    };
    function.block = Box::new(wrapped);

    let bind_args = if args.is_empty() {
        quote!()
    } else {
        quote!((#args))
    };
    quote! {
        #[byondapi::bind #bind_args]
        #function
    }
    .into()
}
