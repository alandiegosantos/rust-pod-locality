"""
@generated
cargo-raze generated Bazel file.

DO NOT EDIT! Replaced on runs of cargo-raze
"""

load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")  # buildifier: disable=load
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")  # buildifier: disable=load

# EXPERIMENTAL -- MAY CHANGE AT ANY TIME: A mapping of package names to a set of normal dependencies for the Rust targets of that package.
_DEPENDENCIES = {
    "": {
        "anyhow": "@raze__anyhow__1_0_61//:anyhow",
        "clap": "@raze__clap__3_2_17//:clap",
        "futures": "@raze__futures__0_3_23//:futures",
        "json-patch": "@raze__json_patch__0_2_6//:json_patch",
        "k8s-openapi": "@raze__k8s_openapi__0_15_0//:k8s_openapi",
        "kube": "@raze__kube__0_74_0//:kube",
        "schemars": "@raze__schemars__0_8_10//:schemars",
        "serde": "@raze__serde__1_0_143//:serde",
        "serde_json": "@raze__serde_json__1_0_83//:serde_json",
        "serde_yaml": "@raze__serde_yaml__0_9_7//:serde_yaml",
        "thiserror": "@raze__thiserror__1_0_32//:thiserror",
        "tokio": "@raze__tokio__1_20_1//:tokio",
        "tracing": "@raze__tracing__0_1_36//:tracing",
        "tracing-subscriber": "@raze__tracing_subscriber__0_3_15//:tracing_subscriber",
        "warp": "@raze__warp__0_3_2//:warp",
    },
}

# EXPERIMENTAL -- MAY CHANGE AT ANY TIME: A mapping of package names to a set of proc_macro dependencies for the Rust targets of that package.
_PROC_MACRO_DEPENDENCIES = {
    "": {
        "kube-derive": "@raze__kube_derive__0_74_0//:kube_derive",
    },
}

# EXPERIMENTAL -- MAY CHANGE AT ANY TIME: A mapping of package names to a set of normal dev dependencies for the Rust targets of that package.
_DEV_DEPENDENCIES = {
    "": {
    },
}

# EXPERIMENTAL -- MAY CHANGE AT ANY TIME: A mapping of package names to a set of proc_macro dev dependencies for the Rust targets of that package.
_DEV_PROC_MACRO_DEPENDENCIES = {
    "": {
    },
}

def crate_deps(deps, package_name = None):
    """EXPERIMENTAL -- MAY CHANGE AT ANY TIME: Finds the fully qualified label of the requested crates for the package where this macro is called.

    WARNING: This macro is part of an expeirmental API and is subject to change.

    Args:
        deps (list): The desired list of crate targets.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.
    Returns:
        list: A list of labels to cargo-raze generated targets (str)
    """

    if not package_name:
        package_name = native.package_name()

    # Join both sets of dependencies
    dependencies = _flatten_dependency_maps([
        _DEPENDENCIES,
        _PROC_MACRO_DEPENDENCIES,
        _DEV_DEPENDENCIES,
        _DEV_PROC_MACRO_DEPENDENCIES,
    ])

    if not deps:
        return []

    missing_crates = []
    crate_targets = []
    for crate_target in deps:
        if crate_target not in dependencies[package_name]:
            missing_crates.append(crate_target)
        else:
            crate_targets.append(dependencies[package_name][crate_target])

    if missing_crates:
        fail("Could not find crates `{}` among dependencies of `{}`. Available dependencies were `{}`".format(
            missing_crates,
            package_name,
            dependencies[package_name],
        ))

    return crate_targets

def all_crate_deps(normal = False, normal_dev = False, proc_macro = False, proc_macro_dev = False, package_name = None):
    """EXPERIMENTAL -- MAY CHANGE AT ANY TIME: Finds the fully qualified label of all requested direct crate dependencies \
    for the package where this macro is called.

    If no parameters are set, all normal dependencies are returned. Setting any one flag will
    otherwise impact the contents of the returned list.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list. Defaults to False.
        normal_dev (bool, optional): If True, normla dev dependencies will be
            included in the output list. Defaults to False.
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list. Defaults to False.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list. Defaults to False.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.

    Returns:
        list: A list of labels to cargo-raze generated targets (str)
    """

    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_dependency_maps = []
    if normal:
        all_dependency_maps.append(_DEPENDENCIES)
    if normal_dev:
        all_dependency_maps.append(_DEV_DEPENDENCIES)
    if proc_macro:
        all_dependency_maps.append(_PROC_MACRO_DEPENDENCIES)
    if proc_macro_dev:
        all_dependency_maps.append(_DEV_PROC_MACRO_DEPENDENCIES)

    # Default to always using normal dependencies
    if not all_dependency_maps:
        all_dependency_maps.append(_DEPENDENCIES)

    dependencies = _flatten_dependency_maps(all_dependency_maps)

    if not dependencies:
        return []

    return dependencies[package_name].values()

def _flatten_dependency_maps(all_dependency_maps):
    """Flatten a list of dependency maps into one dictionary.

    Dependency maps have the following structure:

    ```python
    DEPENDENCIES_MAP = {
        # The first key in the map is a Bazel package
        # name of the workspace this file is defined in.
        "package_name": {

            # An alias to a crate target.     # The label of the crate target the
            # Aliases are only crate names.   # alias refers to.
            "alias":                          "@full//:label",
        }
    }
    ```

    Args:
        all_dependency_maps (list): A list of dicts as described above

    Returns:
        dict: A dictionary as described above
    """
    dependencies = {}

    for dep_map in all_dependency_maps:
        for pkg_name in dep_map:
            if pkg_name not in dependencies:
                # Add a non-frozen dict to the collection of dependencies
                dependencies.setdefault(pkg_name, dict(dep_map[pkg_name].items()))
                continue

            duplicate_crate_aliases = [key for key in dependencies[pkg_name] if key in dep_map[pkg_name]]
            if duplicate_crate_aliases:
                fail("There should be no duplicate crate aliases: {}".format(duplicate_crate_aliases))

            dependencies[pkg_name].update(dep_map[pkg_name])

    return dependencies

def raze_fetch_remote_crates():
    """This function defines a collection of repos and should be called in a WORKSPACE file"""
    maybe(
        http_archive,
        name = "raze__ahash__0_7_6",
        url = "https://crates.io/api/v1/crates/ahash/0.7.6/download",
        type = "tar.gz",
        sha256 = "fcb51a0695d8f838b1ee009b3fbf66bda078cd64590202a864a8f3e8c4315c47",
        strip_prefix = "ahash-0.7.6",
        build_file = Label("//cargo/remote:BUILD.ahash-0.7.6.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__android_system_properties__0_1_4",
        url = "https://crates.io/api/v1/crates/android_system_properties/0.1.4/download",
        type = "tar.gz",
        sha256 = "d7ed72e1635e121ca3e79420540282af22da58be50de153d36f81ddc6b83aa9e",
        strip_prefix = "android_system_properties-0.1.4",
        build_file = Label("//cargo/remote:BUILD.android_system_properties-0.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ansi_term__0_12_1",
        url = "https://crates.io/api/v1/crates/ansi_term/0.12.1/download",
        type = "tar.gz",
        sha256 = "d52a9bb7ec0cf484c551830a7ce27bd20d67eac647e1befb56b0be4ee39a55d2",
        strip_prefix = "ansi_term-0.12.1",
        build_file = Label("//cargo/remote:BUILD.ansi_term-0.12.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__anyhow__1_0_61",
        url = "https://crates.io/api/v1/crates/anyhow/1.0.61/download",
        type = "tar.gz",
        sha256 = "508b352bb5c066aac251f6daf6b36eccd03e8a88e8081cd44959ea277a3af9a8",
        strip_prefix = "anyhow-1.0.61",
        build_file = Label("//cargo/remote:BUILD.anyhow-1.0.61.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__atty__0_2_14",
        url = "https://crates.io/api/v1/crates/atty/0.2.14/download",
        type = "tar.gz",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        strip_prefix = "atty-0.2.14",
        build_file = Label("//cargo/remote:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__autocfg__1_1_0",
        url = "https://crates.io/api/v1/crates/autocfg/1.1.0/download",
        type = "tar.gz",
        sha256 = "d468802bab17cbc0cc575e9b053f41e72aa36bfa6b7f55e3529ffa43161b97fa",
        strip_prefix = "autocfg-1.1.0",
        build_file = Label("//cargo/remote:BUILD.autocfg-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__backoff__0_4_0",
        url = "https://crates.io/api/v1/crates/backoff/0.4.0/download",
        type = "tar.gz",
        sha256 = "b62ddb9cb1ec0a098ad4bbf9344d0713fa193ae1a80af55febcff2627b6a00c1",
        strip_prefix = "backoff-0.4.0",
        build_file = Label("//cargo/remote:BUILD.backoff-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__base64__0_13_0",
        url = "https://crates.io/api/v1/crates/base64/0.13.0/download",
        type = "tar.gz",
        sha256 = "904dfeac50f3cdaba28fc6f57fdcddb75f49ed61346676a78c4ffe55877802fd",
        strip_prefix = "base64-0.13.0",
        build_file = Label("//cargo/remote:BUILD.base64-0.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__bitflags__1_3_2",
        url = "https://crates.io/api/v1/crates/bitflags/1.3.2/download",
        type = "tar.gz",
        sha256 = "bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a",
        strip_prefix = "bitflags-1.3.2",
        build_file = Label("//cargo/remote:BUILD.bitflags-1.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__block_buffer__0_10_2",
        url = "https://crates.io/api/v1/crates/block-buffer/0.10.2/download",
        type = "tar.gz",
        sha256 = "0bf7fe51849ea569fd452f37822f606a5cabb684dc918707a0193fd4664ff324",
        strip_prefix = "block-buffer-0.10.2",
        build_file = Label("//cargo/remote:BUILD.block-buffer-0.10.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__block_buffer__0_9_0",
        url = "https://crates.io/api/v1/crates/block-buffer/0.9.0/download",
        type = "tar.gz",
        sha256 = "4152116fd6e9dadb291ae18fc1ec3575ed6d84c29642d97890f4b4a3417297e4",
        strip_prefix = "block-buffer-0.9.0",
        build_file = Label("//cargo/remote:BUILD.block-buffer-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__buf_redux__0_8_4",
        url = "https://crates.io/api/v1/crates/buf_redux/0.8.4/download",
        type = "tar.gz",
        sha256 = "b953a6887648bb07a535631f2bc00fbdb2a2216f135552cb3f534ed136b9c07f",
        strip_prefix = "buf_redux-0.8.4",
        build_file = Label("//cargo/remote:BUILD.buf_redux-0.8.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__bumpalo__3_10_0",
        url = "https://crates.io/api/v1/crates/bumpalo/3.10.0/download",
        type = "tar.gz",
        sha256 = "37ccbd214614c6783386c1af30caf03192f17891059cecc394b4fb119e363de3",
        strip_prefix = "bumpalo-3.10.0",
        build_file = Label("//cargo/remote:BUILD.bumpalo-3.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__byteorder__1_4_3",
        url = "https://crates.io/api/v1/crates/byteorder/1.4.3/download",
        type = "tar.gz",
        sha256 = "14c189c53d098945499cdfa7ecc63567cf3886b3332b312a5b4585d8d3a6a610",
        strip_prefix = "byteorder-1.4.3",
        build_file = Label("//cargo/remote:BUILD.byteorder-1.4.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__bytes__1_2_1",
        url = "https://crates.io/api/v1/crates/bytes/1.2.1/download",
        type = "tar.gz",
        sha256 = "ec8a7b6a70fde80372154c65702f00a0f56f3e1c36abbc6c440484be248856db",
        strip_prefix = "bytes-1.2.1",
        build_file = Label("//cargo/remote:BUILD.bytes-1.2.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__cc__1_0_73",
        url = "https://crates.io/api/v1/crates/cc/1.0.73/download",
        type = "tar.gz",
        sha256 = "2fff2a6927b3bb87f9595d67196a70493f627687a71d87a0d692242c33f58c11",
        strip_prefix = "cc-1.0.73",
        build_file = Label("//cargo/remote:BUILD.cc-1.0.73.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__cfg_if__1_0_0",
        url = "https://crates.io/api/v1/crates/cfg-if/1.0.0/download",
        type = "tar.gz",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("//cargo/remote:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__chrono__0_4_22",
        url = "https://crates.io/api/v1/crates/chrono/0.4.22/download",
        type = "tar.gz",
        sha256 = "bfd4d1b31faaa3a89d7934dbded3111da0d2ef28e3ebccdb4f0179f5929d1ef1",
        strip_prefix = "chrono-0.4.22",
        build_file = Label("//cargo/remote:BUILD.chrono-0.4.22.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__clap__3_2_17",
        url = "https://crates.io/api/v1/crates/clap/3.2.17/download",
        type = "tar.gz",
        sha256 = "29e724a68d9319343bb3328c9cc2dfde263f4b3142ee1059a9980580171c954b",
        strip_prefix = "clap-3.2.17",
        build_file = Label("//cargo/remote:BUILD.clap-3.2.17.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__clap_derive__3_2_17",
        url = "https://crates.io/api/v1/crates/clap_derive/3.2.17/download",
        type = "tar.gz",
        sha256 = "13547f7012c01ab4a0e8f8967730ada8f9fdf419e8b6c792788f39cf4e46eefa",
        strip_prefix = "clap_derive-3.2.17",
        build_file = Label("//cargo/remote:BUILD.clap_derive-3.2.17.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__clap_lex__0_2_4",
        url = "https://crates.io/api/v1/crates/clap_lex/0.2.4/download",
        type = "tar.gz",
        sha256 = "2850f2f5a82cbf437dd5af4d49848fbdfc27c157c3d010345776f952765261c5",
        strip_prefix = "clap_lex-0.2.4",
        build_file = Label("//cargo/remote:BUILD.clap_lex-0.2.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__core_foundation_sys__0_8_3",
        url = "https://crates.io/api/v1/crates/core-foundation-sys/0.8.3/download",
        type = "tar.gz",
        sha256 = "5827cebf4670468b8772dd191856768aedcb1b0278a04f989f7766351917b9dc",
        strip_prefix = "core-foundation-sys-0.8.3",
        build_file = Label("//cargo/remote:BUILD.core-foundation-sys-0.8.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__cpufeatures__0_2_3",
        url = "https://crates.io/api/v1/crates/cpufeatures/0.2.3/download",
        type = "tar.gz",
        sha256 = "1079fb8528d9f9c888b1e8aa651e6e079ade467323d58f75faf1d30b1808f540",
        strip_prefix = "cpufeatures-0.2.3",
        build_file = Label("//cargo/remote:BUILD.cpufeatures-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__crypto_common__0_1_6",
        url = "https://crates.io/api/v1/crates/crypto-common/0.1.6/download",
        type = "tar.gz",
        sha256 = "1bfb12502f3fc46cca1bb51ac28df9d618d813cdc3d2f25b9fe775a34af26bb3",
        strip_prefix = "crypto-common-0.1.6",
        build_file = Label("//cargo/remote:BUILD.crypto-common-0.1.6.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__darling__0_14_1",
        url = "https://crates.io/api/v1/crates/darling/0.14.1/download",
        type = "tar.gz",
        sha256 = "4529658bdda7fd6769b8614be250cdcfc3aeb0ee72fe66f9e41e5e5eb73eac02",
        strip_prefix = "darling-0.14.1",
        build_file = Label("//cargo/remote:BUILD.darling-0.14.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__darling_core__0_14_1",
        url = "https://crates.io/api/v1/crates/darling_core/0.14.1/download",
        type = "tar.gz",
        sha256 = "649c91bc01e8b1eac09fb91e8dbc7d517684ca6be8ebc75bb9cafc894f9fdb6f",
        strip_prefix = "darling_core-0.14.1",
        build_file = Label("//cargo/remote:BUILD.darling_core-0.14.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__darling_macro__0_14_1",
        url = "https://crates.io/api/v1/crates/darling_macro/0.14.1/download",
        type = "tar.gz",
        sha256 = "ddfc69c5bfcbd2fc09a0f38451d2daf0e372e367986a83906d1b0dbc88134fb5",
        strip_prefix = "darling_macro-0.14.1",
        build_file = Label("//cargo/remote:BUILD.darling_macro-0.14.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__derivative__2_2_0",
        url = "https://crates.io/api/v1/crates/derivative/2.2.0/download",
        type = "tar.gz",
        sha256 = "fcc3dd5e9e9c0b295d6e1e4d811fb6f157d5ffd784b8d202fc62eac8035a770b",
        strip_prefix = "derivative-2.2.0",
        build_file = Label("//cargo/remote:BUILD.derivative-2.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__digest__0_10_3",
        url = "https://crates.io/api/v1/crates/digest/0.10.3/download",
        type = "tar.gz",
        sha256 = "f2fb860ca6fafa5552fb6d0e816a69c8e49f0908bf524e30a90d97c85892d506",
        strip_prefix = "digest-0.10.3",
        build_file = Label("//cargo/remote:BUILD.digest-0.10.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__digest__0_9_0",
        url = "https://crates.io/api/v1/crates/digest/0.9.0/download",
        type = "tar.gz",
        sha256 = "d3dd60d1080a57a05ab032377049e0591415d2b31afd7028356dbf3cc6dcb066",
        strip_prefix = "digest-0.9.0",
        build_file = Label("//cargo/remote:BUILD.digest-0.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__dirs_next__2_0_0",
        url = "https://crates.io/api/v1/crates/dirs-next/2.0.0/download",
        type = "tar.gz",
        sha256 = "b98cf8ebf19c3d1b223e151f99a4f9f0690dca41414773390fc824184ac833e1",
        strip_prefix = "dirs-next-2.0.0",
        build_file = Label("//cargo/remote:BUILD.dirs-next-2.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__dirs_sys_next__0_1_2",
        url = "https://crates.io/api/v1/crates/dirs-sys-next/0.1.2/download",
        type = "tar.gz",
        sha256 = "4ebda144c4fe02d1f7ea1a7d9641b6fc6b580adcfa024ae48797ecdeb6825b4d",
        strip_prefix = "dirs-sys-next-0.1.2",
        build_file = Label("//cargo/remote:BUILD.dirs-sys-next-0.1.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__dyn_clone__1_0_9",
        url = "https://crates.io/api/v1/crates/dyn-clone/1.0.9/download",
        type = "tar.gz",
        sha256 = "4f94fa09c2aeea5b8839e414b7b841bf429fd25b9c522116ac97ee87856d88b2",
        strip_prefix = "dyn-clone-1.0.9",
        build_file = Label("//cargo/remote:BUILD.dyn-clone-1.0.9.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__either__1_7_0",
        url = "https://crates.io/api/v1/crates/either/1.7.0/download",
        type = "tar.gz",
        sha256 = "3f107b87b6afc2a64fd13cac55fe06d6c8859f12d4b14cbcdd2c67d0976781be",
        strip_prefix = "either-1.7.0",
        build_file = Label("//cargo/remote:BUILD.either-1.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__fastrand__1_8_0",
        url = "https://crates.io/api/v1/crates/fastrand/1.8.0/download",
        type = "tar.gz",
        sha256 = "a7a407cfaa3385c4ae6b23e84623d48c2798d06e3e6a1878f7f59f17b3f86499",
        strip_prefix = "fastrand-1.8.0",
        build_file = Label("//cargo/remote:BUILD.fastrand-1.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__fnv__1_0_7",
        url = "https://crates.io/api/v1/crates/fnv/1.0.7/download",
        type = "tar.gz",
        sha256 = "3f9eec918d3f24069decb9af1554cad7c880e2da24a9afd88aca000531ab82c1",
        strip_prefix = "fnv-1.0.7",
        build_file = Label("//cargo/remote:BUILD.fnv-1.0.7.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__foreign_types__0_3_2",
        url = "https://crates.io/api/v1/crates/foreign-types/0.3.2/download",
        type = "tar.gz",
        sha256 = "f6f339eb8adc052cd2ca78910fda869aefa38d22d5cb648e6485e4d3fc06f3b1",
        strip_prefix = "foreign-types-0.3.2",
        build_file = Label("//cargo/remote:BUILD.foreign-types-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__foreign_types_shared__0_1_1",
        url = "https://crates.io/api/v1/crates/foreign-types-shared/0.1.1/download",
        type = "tar.gz",
        sha256 = "00b0228411908ca8685dba7fc2cdd70ec9990a6e753e89b6ac91a84c40fbaf4b",
        strip_prefix = "foreign-types-shared-0.1.1",
        build_file = Label("//cargo/remote:BUILD.foreign-types-shared-0.1.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__form_urlencoded__1_0_1",
        url = "https://crates.io/api/v1/crates/form_urlencoded/1.0.1/download",
        type = "tar.gz",
        sha256 = "5fc25a87fa4fd2094bffb06925852034d90a17f0d1e05197d4956d3555752191",
        strip_prefix = "form_urlencoded-1.0.1",
        build_file = Label("//cargo/remote:BUILD.form_urlencoded-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__futures__0_3_23",
        url = "https://crates.io/api/v1/crates/futures/0.3.23/download",
        type = "tar.gz",
        sha256 = "ab30e97ab6aacfe635fad58f22c2bb06c8b685f7421eb1e064a729e2a5f481fa",
        strip_prefix = "futures-0.3.23",
        build_file = Label("//cargo/remote:BUILD.futures-0.3.23.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__futures_channel__0_3_23",
        url = "https://crates.io/api/v1/crates/futures-channel/0.3.23/download",
        type = "tar.gz",
        sha256 = "2bfc52cbddcfd745bf1740338492bb0bd83d76c67b445f91c5fb29fae29ecaa1",
        strip_prefix = "futures-channel-0.3.23",
        build_file = Label("//cargo/remote:BUILD.futures-channel-0.3.23.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__futures_core__0_3_23",
        url = "https://crates.io/api/v1/crates/futures-core/0.3.23/download",
        type = "tar.gz",
        sha256 = "d2acedae88d38235936c3922476b10fced7b2b68136f5e3c03c2d5be348a1115",
        strip_prefix = "futures-core-0.3.23",
        build_file = Label("//cargo/remote:BUILD.futures-core-0.3.23.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__futures_executor__0_3_23",
        url = "https://crates.io/api/v1/crates/futures-executor/0.3.23/download",
        type = "tar.gz",
        sha256 = "1d11aa21b5b587a64682c0094c2bdd4df0076c5324961a40cc3abd7f37930528",
        strip_prefix = "futures-executor-0.3.23",
        build_file = Label("//cargo/remote:BUILD.futures-executor-0.3.23.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__futures_io__0_3_23",
        url = "https://crates.io/api/v1/crates/futures-io/0.3.23/download",
        type = "tar.gz",
        sha256 = "93a66fc6d035a26a3ae255a6d2bca35eda63ae4c5512bef54449113f7a1228e5",
        strip_prefix = "futures-io-0.3.23",
        build_file = Label("//cargo/remote:BUILD.futures-io-0.3.23.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__futures_macro__0_3_23",
        url = "https://crates.io/api/v1/crates/futures-macro/0.3.23/download",
        type = "tar.gz",
        sha256 = "0db9cce532b0eae2ccf2766ab246f114b56b9cf6d445e00c2549fbc100ca045d",
        strip_prefix = "futures-macro-0.3.23",
        build_file = Label("//cargo/remote:BUILD.futures-macro-0.3.23.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__futures_sink__0_3_23",
        url = "https://crates.io/api/v1/crates/futures-sink/0.3.23/download",
        type = "tar.gz",
        sha256 = "ca0bae1fe9752cf7fd9b0064c674ae63f97b37bc714d745cbde0afb7ec4e6765",
        strip_prefix = "futures-sink-0.3.23",
        build_file = Label("//cargo/remote:BUILD.futures-sink-0.3.23.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__futures_task__0_3_23",
        url = "https://crates.io/api/v1/crates/futures-task/0.3.23/download",
        type = "tar.gz",
        sha256 = "842fc63b931f4056a24d59de13fb1272134ce261816e063e634ad0c15cdc5306",
        strip_prefix = "futures-task-0.3.23",
        build_file = Label("//cargo/remote:BUILD.futures-task-0.3.23.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__futures_util__0_3_23",
        url = "https://crates.io/api/v1/crates/futures-util/0.3.23/download",
        type = "tar.gz",
        sha256 = "f0828a5471e340229c11c77ca80017937ce3c58cb788a17e5f1c2d5c485a9577",
        strip_prefix = "futures-util-0.3.23",
        build_file = Label("//cargo/remote:BUILD.futures-util-0.3.23.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__generic_array__0_14_6",
        url = "https://crates.io/api/v1/crates/generic-array/0.14.6/download",
        type = "tar.gz",
        sha256 = "bff49e947297f3312447abdca79f45f4738097cc82b06e72054d2223f601f1b9",
        strip_prefix = "generic-array-0.14.6",
        build_file = Label("//cargo/remote:BUILD.generic-array-0.14.6.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__getrandom__0_2_7",
        url = "https://crates.io/api/v1/crates/getrandom/0.2.7/download",
        type = "tar.gz",
        sha256 = "4eb1a864a501629691edf6c15a593b7a51eebaa1e8468e9ddc623de7c9b58ec6",
        strip_prefix = "getrandom-0.2.7",
        build_file = Label("//cargo/remote:BUILD.getrandom-0.2.7.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__h2__0_3_14",
        url = "https://crates.io/api/v1/crates/h2/0.3.14/download",
        type = "tar.gz",
        sha256 = "5ca32592cf21ac7ccab1825cd87f6c9b3d9022c44d086172ed0966bec8af30be",
        strip_prefix = "h2-0.3.14",
        build_file = Label("//cargo/remote:BUILD.h2-0.3.14.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__hashbrown__0_12_3",
        url = "https://crates.io/api/v1/crates/hashbrown/0.12.3/download",
        type = "tar.gz",
        sha256 = "8a9ee70c43aaf417c914396645a0fa852624801b24ebb7ae78fe8272889ac888",
        strip_prefix = "hashbrown-0.12.3",
        build_file = Label("//cargo/remote:BUILD.hashbrown-0.12.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__headers__0_3_7",
        url = "https://crates.io/api/v1/crates/headers/0.3.7/download",
        type = "tar.gz",
        sha256 = "4cff78e5788be1e0ab65b04d306b2ed5092c815ec97ec70f4ebd5aee158aa55d",
        strip_prefix = "headers-0.3.7",
        build_file = Label("//cargo/remote:BUILD.headers-0.3.7.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__headers_core__0_2_0",
        url = "https://crates.io/api/v1/crates/headers-core/0.2.0/download",
        type = "tar.gz",
        sha256 = "e7f66481bfee273957b1f20485a4ff3362987f85b2c236580d81b4eb7a326429",
        strip_prefix = "headers-core-0.2.0",
        build_file = Label("//cargo/remote:BUILD.headers-core-0.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__heck__0_4_0",
        url = "https://crates.io/api/v1/crates/heck/0.4.0/download",
        type = "tar.gz",
        sha256 = "2540771e65fc8cb83cd6e8a237f70c319bd5c29f78ed1084ba5d50eeac86f7f9",
        strip_prefix = "heck-0.4.0",
        build_file = Label("//cargo/remote:BUILD.heck-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__hermit_abi__0_1_19",
        url = "https://crates.io/api/v1/crates/hermit-abi/0.1.19/download",
        type = "tar.gz",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("//cargo/remote:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__http__0_2_8",
        url = "https://crates.io/api/v1/crates/http/0.2.8/download",
        type = "tar.gz",
        sha256 = "75f43d41e26995c17e71ee126451dd3941010b0514a81a9d11f3b341debc2399",
        strip_prefix = "http-0.2.8",
        build_file = Label("//cargo/remote:BUILD.http-0.2.8.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__http_body__0_4_5",
        url = "https://crates.io/api/v1/crates/http-body/0.4.5/download",
        type = "tar.gz",
        sha256 = "d5f38f16d184e36f2408a55281cd658ecbd3ca05cce6d6510a176eca393e26d1",
        strip_prefix = "http-body-0.4.5",
        build_file = Label("//cargo/remote:BUILD.http-body-0.4.5.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__http_range_header__0_3_0",
        url = "https://crates.io/api/v1/crates/http-range-header/0.3.0/download",
        type = "tar.gz",
        sha256 = "0bfe8eed0a9285ef776bb792479ea3834e8b94e13d615c2f66d03dd50a435a29",
        strip_prefix = "http-range-header-0.3.0",
        build_file = Label("//cargo/remote:BUILD.http-range-header-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__httparse__1_7_1",
        url = "https://crates.io/api/v1/crates/httparse/1.7.1/download",
        type = "tar.gz",
        sha256 = "496ce29bb5a52785b44e0f7ca2847ae0bb839c9bd28f69acac9b99d461c0c04c",
        strip_prefix = "httparse-1.7.1",
        build_file = Label("//cargo/remote:BUILD.httparse-1.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__httpdate__1_0_2",
        url = "https://crates.io/api/v1/crates/httpdate/1.0.2/download",
        type = "tar.gz",
        sha256 = "c4a1e36c821dbe04574f602848a19f742f4fb3c98d40449f11bcad18d6b17421",
        strip_prefix = "httpdate-1.0.2",
        build_file = Label("//cargo/remote:BUILD.httpdate-1.0.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__hyper__0_14_20",
        url = "https://crates.io/api/v1/crates/hyper/0.14.20/download",
        type = "tar.gz",
        sha256 = "02c929dc5c39e335a03c405292728118860721b10190d98c2a0f0efd5baafbac",
        strip_prefix = "hyper-0.14.20",
        build_file = Label("//cargo/remote:BUILD.hyper-0.14.20.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__hyper_openssl__0_9_2",
        url = "https://crates.io/api/v1/crates/hyper-openssl/0.9.2/download",
        type = "tar.gz",
        sha256 = "d6ee5d7a8f718585d1c3c61dfde28ef5b0bb14734b4db13f5ada856cdc6c612b",
        strip_prefix = "hyper-openssl-0.9.2",
        build_file = Label("//cargo/remote:BUILD.hyper-openssl-0.9.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__hyper_timeout__0_4_1",
        url = "https://crates.io/api/v1/crates/hyper-timeout/0.4.1/download",
        type = "tar.gz",
        sha256 = "bbb958482e8c7be4bc3cf272a766a2b0bf1a6755e7a6ae777f017a31d11b13b1",
        strip_prefix = "hyper-timeout-0.4.1",
        build_file = Label("//cargo/remote:BUILD.hyper-timeout-0.4.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__iana_time_zone__0_1_44",
        url = "https://crates.io/api/v1/crates/iana-time-zone/0.1.44/download",
        type = "tar.gz",
        sha256 = "808cf7d67cf4a22adc5be66e75ebdf769b3f2ea032041437a7061f97a63dad4b",
        strip_prefix = "iana-time-zone-0.1.44",
        build_file = Label("//cargo/remote:BUILD.iana-time-zone-0.1.44.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ident_case__1_0_1",
        url = "https://crates.io/api/v1/crates/ident_case/1.0.1/download",
        type = "tar.gz",
        sha256 = "b9e0384b61958566e926dc50660321d12159025e767c18e043daf26b70104c39",
        strip_prefix = "ident_case-1.0.1",
        build_file = Label("//cargo/remote:BUILD.ident_case-1.0.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__idna__0_2_3",
        url = "https://crates.io/api/v1/crates/idna/0.2.3/download",
        type = "tar.gz",
        sha256 = "418a0a6fab821475f634efe3ccc45c013f742efe03d853e8d3355d5cb850ecf8",
        strip_prefix = "idna-0.2.3",
        build_file = Label("//cargo/remote:BUILD.idna-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__indexmap__1_9_1",
        url = "https://crates.io/api/v1/crates/indexmap/1.9.1/download",
        type = "tar.gz",
        sha256 = "10a35a97730320ffe8e2d410b5d3b69279b98d2c14bdb8b70ea89ecf7888d41e",
        strip_prefix = "indexmap-1.9.1",
        build_file = Label("//cargo/remote:BUILD.indexmap-1.9.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__instant__0_1_12",
        url = "https://crates.io/api/v1/crates/instant/0.1.12/download",
        type = "tar.gz",
        sha256 = "7a5bbe824c507c5da5956355e86a746d82e0e1464f65d862cc5e71da70e94b2c",
        strip_prefix = "instant-0.1.12",
        build_file = Label("//cargo/remote:BUILD.instant-0.1.12.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__itoa__1_0_3",
        url = "https://crates.io/api/v1/crates/itoa/1.0.3/download",
        type = "tar.gz",
        sha256 = "6c8af84674fe1f223a982c933a0ee1086ac4d4052aa0fb8060c12c6ad838e754",
        strip_prefix = "itoa-1.0.3",
        build_file = Label("//cargo/remote:BUILD.itoa-1.0.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__js_sys__0_3_59",
        url = "https://crates.io/api/v1/crates/js-sys/0.3.59/download",
        type = "tar.gz",
        sha256 = "258451ab10b34f8af53416d1fdab72c22e805f0c92a1136d59470ec0b11138b2",
        strip_prefix = "js-sys-0.3.59",
        build_file = Label("//cargo/remote:BUILD.js-sys-0.3.59.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__json_patch__0_2_6",
        url = "https://crates.io/api/v1/crates/json-patch/0.2.6/download",
        type = "tar.gz",
        sha256 = "f995a3c8f2bc3dd52a18a583e90f9ec109c047fa1603a853e46bcda14d2e279d",
        strip_prefix = "json-patch-0.2.6",
        build_file = Label("//cargo/remote:BUILD.json-patch-0.2.6.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__jsonpath_lib__0_3_0",
        url = "https://crates.io/api/v1/crates/jsonpath_lib/0.3.0/download",
        type = "tar.gz",
        sha256 = "eaa63191d68230cccb81c5aa23abd53ed64d83337cacbb25a7b8c7979523774f",
        strip_prefix = "jsonpath_lib-0.3.0",
        build_file = Label("//cargo/remote:BUILD.jsonpath_lib-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__k8s_openapi__0_15_0",
        url = "https://crates.io/api/v1/crates/k8s-openapi/0.15.0/download",
        type = "tar.gz",
        sha256 = "d2ae2c04fcee6b01b04e3aadd56bb418932c8e0a9d8a93f48bc68c6bdcdb559d",
        strip_prefix = "k8s-openapi-0.15.0",
        build_file = Label("//cargo/remote:BUILD.k8s-openapi-0.15.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__kube__0_74_0",
        url = "https://crates.io/api/v1/crates/kube/0.74.0/download",
        type = "tar.gz",
        sha256 = "a527a8001a61d8d470dab27ac650889938760c243903e7cd90faaf7c60a34bdd",
        strip_prefix = "kube-0.74.0",
        build_file = Label("//cargo/remote:BUILD.kube-0.74.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__kube_client__0_74_0",
        url = "https://crates.io/api/v1/crates/kube-client/0.74.0/download",
        type = "tar.gz",
        sha256 = "c0d48f42df4e8342e9f488c4b97e3759d0042c4e7ab1a853cc285adb44409480",
        strip_prefix = "kube-client-0.74.0",
        build_file = Label("//cargo/remote:BUILD.kube-client-0.74.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__kube_core__0_74_0",
        url = "https://crates.io/api/v1/crates/kube-core/0.74.0/download",
        type = "tar.gz",
        sha256 = "91f56027f862fdcad265d2e9616af416a355e28a1c620bb709083494753e070d",
        strip_prefix = "kube-core-0.74.0",
        build_file = Label("//cargo/remote:BUILD.kube-core-0.74.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__kube_derive__0_74_0",
        url = "https://crates.io/api/v1/crates/kube-derive/0.74.0/download",
        type = "tar.gz",
        sha256 = "66d74121eb41af4480052901f31142d8d9bbdf1b7c6b856da43bcb02f5b1b177",
        strip_prefix = "kube-derive-0.74.0",
        build_file = Label("//cargo/remote:BUILD.kube-derive-0.74.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__kube_runtime__0_74_0",
        url = "https://crates.io/api/v1/crates/kube-runtime/0.74.0/download",
        type = "tar.gz",
        sha256 = "8fdcf5a20f968768e342ef1a457491bb5661fccd81119666d626c57500b16d99",
        strip_prefix = "kube-runtime-0.74.0",
        build_file = Label("//cargo/remote:BUILD.kube-runtime-0.74.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__lazy_static__1_4_0",
        url = "https://crates.io/api/v1/crates/lazy_static/1.4.0/download",
        type = "tar.gz",
        sha256 = "e2abad23fbc42b3700f2f279844dc832adb2b2eb069b2df918f455c4e18cc646",
        strip_prefix = "lazy_static-1.4.0",
        build_file = Label("//cargo/remote:BUILD.lazy_static-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__libc__0_2_131",
        url = "https://crates.io/api/v1/crates/libc/0.2.131/download",
        type = "tar.gz",
        sha256 = "04c3b4822ccebfa39c02fc03d1534441b22ead323fa0f48bb7ddd8e6ba076a40",
        strip_prefix = "libc-0.2.131",
        build_file = Label("//cargo/remote:BUILD.libc-0.2.131.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__linked_hash_map__0_5_6",
        url = "https://crates.io/api/v1/crates/linked-hash-map/0.5.6/download",
        type = "tar.gz",
        sha256 = "0717cef1bc8b636c6e1c1bbdefc09e6322da8a9321966e8928ef80d20f7f770f",
        strip_prefix = "linked-hash-map-0.5.6",
        build_file = Label("//cargo/remote:BUILD.linked-hash-map-0.5.6.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__linked_hash_set__0_1_4",
        url = "https://crates.io/api/v1/crates/linked_hash_set/0.1.4/download",
        type = "tar.gz",
        sha256 = "47186c6da4d81ca383c7c47c1bfc80f4b95f4720514d860a5407aaf4233f9588",
        strip_prefix = "linked_hash_set-0.1.4",
        build_file = Label("//cargo/remote:BUILD.linked_hash_set-0.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__lock_api__0_4_7",
        url = "https://crates.io/api/v1/crates/lock_api/0.4.7/download",
        type = "tar.gz",
        sha256 = "327fa5b6a6940e4699ec49a9beae1ea4845c6bab9314e4f84ac68742139d8c53",
        strip_prefix = "lock_api-0.4.7",
        build_file = Label("//cargo/remote:BUILD.lock_api-0.4.7.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__log__0_4_17",
        url = "https://crates.io/api/v1/crates/log/0.4.17/download",
        type = "tar.gz",
        sha256 = "abb12e687cfb44aa40f41fc3978ef76448f9b6038cad6aef4259d3c095a2382e",
        strip_prefix = "log-0.4.17",
        build_file = Label("//cargo/remote:BUILD.log-0.4.17.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__matches__0_1_9",
        url = "https://crates.io/api/v1/crates/matches/0.1.9/download",
        type = "tar.gz",
        sha256 = "a3e378b66a060d48947b590737b30a1be76706c8dd7b8ba0f2fe3989c68a853f",
        strip_prefix = "matches-0.1.9",
        build_file = Label("//cargo/remote:BUILD.matches-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__memchr__2_5_0",
        url = "https://crates.io/api/v1/crates/memchr/2.5.0/download",
        type = "tar.gz",
        sha256 = "2dffe52ecf27772e601905b7522cb4ef790d2cc203488bbd0e2fe85fcb74566d",
        strip_prefix = "memchr-2.5.0",
        build_file = Label("//cargo/remote:BUILD.memchr-2.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__mime__0_3_16",
        url = "https://crates.io/api/v1/crates/mime/0.3.16/download",
        type = "tar.gz",
        sha256 = "2a60c7ce501c71e03a9c9c0d35b861413ae925bd979cc7a4e30d060069aaac8d",
        strip_prefix = "mime-0.3.16",
        build_file = Label("//cargo/remote:BUILD.mime-0.3.16.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__mime_guess__2_0_4",
        url = "https://crates.io/api/v1/crates/mime_guess/2.0.4/download",
        type = "tar.gz",
        sha256 = "4192263c238a5f0d0c6bfd21f336a313a4ce1c450542449ca191bb657b4642ef",
        strip_prefix = "mime_guess-2.0.4",
        build_file = Label("//cargo/remote:BUILD.mime_guess-2.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__mio__0_8_4",
        url = "https://crates.io/api/v1/crates/mio/0.8.4/download",
        type = "tar.gz",
        sha256 = "57ee1c23c7c63b0c9250c339ffdc69255f110b298b901b9f6c82547b7b87caaf",
        strip_prefix = "mio-0.8.4",
        build_file = Label("//cargo/remote:BUILD.mio-0.8.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__multipart__0_18_0",
        url = "https://crates.io/api/v1/crates/multipart/0.18.0/download",
        type = "tar.gz",
        sha256 = "00dec633863867f29cb39df64a397cdf4a6354708ddd7759f70c7fb51c5f9182",
        strip_prefix = "multipart-0.18.0",
        build_file = Label("//cargo/remote:BUILD.multipart-0.18.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__num_integer__0_1_45",
        url = "https://crates.io/api/v1/crates/num-integer/0.1.45/download",
        type = "tar.gz",
        sha256 = "225d3389fb3509a24c93f5c29eb6bde2586b98d9f016636dff58d7c6f7569cd9",
        strip_prefix = "num-integer-0.1.45",
        build_file = Label("//cargo/remote:BUILD.num-integer-0.1.45.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__num_traits__0_2_15",
        url = "https://crates.io/api/v1/crates/num-traits/0.2.15/download",
        type = "tar.gz",
        sha256 = "578ede34cf02f8924ab9447f50c28075b4d3e5b269972345e7e0372b38c6cdcd",
        strip_prefix = "num-traits-0.2.15",
        build_file = Label("//cargo/remote:BUILD.num-traits-0.2.15.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__num_cpus__1_13_1",
        url = "https://crates.io/api/v1/crates/num_cpus/1.13.1/download",
        type = "tar.gz",
        sha256 = "19e64526ebdee182341572e50e9ad03965aa510cd94427a4549448f285e957a1",
        strip_prefix = "num_cpus-1.13.1",
        build_file = Label("//cargo/remote:BUILD.num_cpus-1.13.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__once_cell__1_13_0",
        url = "https://crates.io/api/v1/crates/once_cell/1.13.0/download",
        type = "tar.gz",
        sha256 = "18a6dbe30758c9f83eb00cbea4ac95966305f5a7772f3f42ebfc7fc7eddbd8e1",
        strip_prefix = "once_cell-1.13.0",
        build_file = Label("//cargo/remote:BUILD.once_cell-1.13.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__opaque_debug__0_3_0",
        url = "https://crates.io/api/v1/crates/opaque-debug/0.3.0/download",
        type = "tar.gz",
        sha256 = "624a8340c38c1b80fd549087862da4ba43e08858af025b236e509b6649fc13d5",
        strip_prefix = "opaque-debug-0.3.0",
        build_file = Label("//cargo/remote:BUILD.opaque-debug-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__openssl__0_10_41",
        url = "https://crates.io/api/v1/crates/openssl/0.10.41/download",
        type = "tar.gz",
        sha256 = "618febf65336490dfcf20b73f885f5651a0c89c64c2d4a8c3662585a70bf5bd0",
        strip_prefix = "openssl-0.10.41",
        build_file = Label("//cargo/remote:BUILD.openssl-0.10.41.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__openssl_macros__0_1_0",
        url = "https://crates.io/api/v1/crates/openssl-macros/0.1.0/download",
        type = "tar.gz",
        sha256 = "b501e44f11665960c7e7fcf062c7d96a14ade4aa98116c004b2e37b5be7d736c",
        strip_prefix = "openssl-macros-0.1.0",
        build_file = Label("//cargo/remote:BUILD.openssl-macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__openssl_sys__0_9_75",
        url = "https://crates.io/api/v1/crates/openssl-sys/0.9.75/download",
        type = "tar.gz",
        sha256 = "e5f9bd0c2710541a3cda73d6f9ac4f1b240de4ae261065d309dbe73d9dceb42f",
        strip_prefix = "openssl-sys-0.9.75",
        build_file = Label("//cargo/remote:BUILD.openssl-sys-0.9.75.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ordered_float__2_10_0",
        url = "https://crates.io/api/v1/crates/ordered-float/2.10.0/download",
        type = "tar.gz",
        sha256 = "7940cf2ca942593318d07fcf2596cdca60a85c9e7fab408a5e21a4f9dcd40d87",
        strip_prefix = "ordered-float-2.10.0",
        build_file = Label("//cargo/remote:BUILD.ordered-float-2.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__os_str_bytes__6_3_0",
        url = "https://crates.io/api/v1/crates/os_str_bytes/6.3.0/download",
        type = "tar.gz",
        sha256 = "9ff7415e9ae3fff1225851df9e0d9e4e5479f947619774677a63572e55e80eff",
        strip_prefix = "os_str_bytes-6.3.0",
        build_file = Label("//cargo/remote:BUILD.os_str_bytes-6.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__parking_lot__0_12_1",
        url = "https://crates.io/api/v1/crates/parking_lot/0.12.1/download",
        type = "tar.gz",
        sha256 = "3742b2c103b9f06bc9fff0a37ff4912935851bee6d36f3c02bcc755bcfec228f",
        strip_prefix = "parking_lot-0.12.1",
        build_file = Label("//cargo/remote:BUILD.parking_lot-0.12.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__parking_lot_core__0_9_3",
        url = "https://crates.io/api/v1/crates/parking_lot_core/0.9.3/download",
        type = "tar.gz",
        sha256 = "09a279cbf25cb0757810394fbc1e359949b59e348145c643a939a525692e6929",
        strip_prefix = "parking_lot_core-0.9.3",
        build_file = Label("//cargo/remote:BUILD.parking_lot_core-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__pem__1_1_0",
        url = "https://crates.io/api/v1/crates/pem/1.1.0/download",
        type = "tar.gz",
        sha256 = "03c64931a1a212348ec4f3b4362585eca7159d0d09cbdf4a7f74f02173596fd4",
        strip_prefix = "pem-1.1.0",
        build_file = Label("//cargo/remote:BUILD.pem-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__percent_encoding__2_1_0",
        url = "https://crates.io/api/v1/crates/percent-encoding/2.1.0/download",
        type = "tar.gz",
        sha256 = "d4fd5641d01c8f18a23da7b6fe29298ff4b55afcccdf78973b24cf3175fee32e",
        strip_prefix = "percent-encoding-2.1.0",
        build_file = Label("//cargo/remote:BUILD.percent-encoding-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__pin_project__1_0_11",
        url = "https://crates.io/api/v1/crates/pin-project/1.0.11/download",
        type = "tar.gz",
        sha256 = "78203e83c48cffbe01e4a2d35d566ca4de445d79a85372fc64e378bfc812a260",
        strip_prefix = "pin-project-1.0.11",
        build_file = Label("//cargo/remote:BUILD.pin-project-1.0.11.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__pin_project_internal__1_0_11",
        url = "https://crates.io/api/v1/crates/pin-project-internal/1.0.11/download",
        type = "tar.gz",
        sha256 = "710faf75e1b33345361201d36d04e98ac1ed8909151a017ed384700836104c74",
        strip_prefix = "pin-project-internal-1.0.11",
        build_file = Label("//cargo/remote:BUILD.pin-project-internal-1.0.11.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__pin_project_lite__0_2_9",
        url = "https://crates.io/api/v1/crates/pin-project-lite/0.2.9/download",
        type = "tar.gz",
        sha256 = "e0a7ae3ac2f1173085d398531c705756c94a4c56843785df85a60c1a0afac116",
        strip_prefix = "pin-project-lite-0.2.9",
        build_file = Label("//cargo/remote:BUILD.pin-project-lite-0.2.9.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__pin_utils__0_1_0",
        url = "https://crates.io/api/v1/crates/pin-utils/0.1.0/download",
        type = "tar.gz",
        sha256 = "8b870d8c151b6f2fb93e84a13146138f05d02ed11c7e7c54f8826aaaf7c9f184",
        strip_prefix = "pin-utils-0.1.0",
        build_file = Label("//cargo/remote:BUILD.pin-utils-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__pkg_config__0_3_25",
        url = "https://crates.io/api/v1/crates/pkg-config/0.3.25/download",
        type = "tar.gz",
        sha256 = "1df8c4ec4b0627e53bdf214615ad287367e482558cf84b109250b37464dc03ae",
        strip_prefix = "pkg-config-0.3.25",
        build_file = Label("//cargo/remote:BUILD.pkg-config-0.3.25.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ppv_lite86__0_2_16",
        url = "https://crates.io/api/v1/crates/ppv-lite86/0.2.16/download",
        type = "tar.gz",
        sha256 = "eb9f9e6e233e5c4a35559a617bf40a4ec447db2e84c20b55a6f83167b7e57872",
        strip_prefix = "ppv-lite86-0.2.16",
        build_file = Label("//cargo/remote:BUILD.ppv-lite86-0.2.16.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__proc_macro_error__1_0_4",
        url = "https://crates.io/api/v1/crates/proc-macro-error/1.0.4/download",
        type = "tar.gz",
        sha256 = "da25490ff9892aab3fcf7c36f08cfb902dd3e71ca0f9f9517bea02a73a5ce38c",
        strip_prefix = "proc-macro-error-1.0.4",
        build_file = Label("//cargo/remote:BUILD.proc-macro-error-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__proc_macro_error_attr__1_0_4",
        url = "https://crates.io/api/v1/crates/proc-macro-error-attr/1.0.4/download",
        type = "tar.gz",
        sha256 = "a1be40180e52ecc98ad80b184934baf3d0d29f979574e439af5a55274b35f869",
        strip_prefix = "proc-macro-error-attr-1.0.4",
        build_file = Label("//cargo/remote:BUILD.proc-macro-error-attr-1.0.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__proc_macro2__1_0_43",
        url = "https://crates.io/api/v1/crates/proc-macro2/1.0.43/download",
        type = "tar.gz",
        sha256 = "0a2ca2c61bc9f3d74d2886294ab7b9853abd9c1ad903a3ac7815c58989bb7bab",
        strip_prefix = "proc-macro2-1.0.43",
        build_file = Label("//cargo/remote:BUILD.proc-macro2-1.0.43.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__quick_error__1_2_3",
        url = "https://crates.io/api/v1/crates/quick-error/1.2.3/download",
        type = "tar.gz",
        sha256 = "a1d01941d82fa2ab50be1e79e6714289dd7cde78eba4c074bc5a4374f650dfe0",
        strip_prefix = "quick-error-1.2.3",
        build_file = Label("//cargo/remote:BUILD.quick-error-1.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__quote__1_0_21",
        url = "https://crates.io/api/v1/crates/quote/1.0.21/download",
        type = "tar.gz",
        sha256 = "bbe448f377a7d6961e30f5955f9b8d106c3f5e449d493ee1b125c1d43c2b5179",
        strip_prefix = "quote-1.0.21",
        build_file = Label("//cargo/remote:BUILD.quote-1.0.21.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rand__0_8_5",
        url = "https://crates.io/api/v1/crates/rand/0.8.5/download",
        type = "tar.gz",
        sha256 = "34af8d1a0e25924bc5b7c43c079c942339d8f0a8b57c39049bef581b46327404",
        strip_prefix = "rand-0.8.5",
        build_file = Label("//cargo/remote:BUILD.rand-0.8.5.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rand_chacha__0_3_1",
        url = "https://crates.io/api/v1/crates/rand_chacha/0.3.1/download",
        type = "tar.gz",
        sha256 = "e6c10a63a0fa32252be49d21e7709d4d4baf8d231c2dbce1eaa8141b9b127d88",
        strip_prefix = "rand_chacha-0.3.1",
        build_file = Label("//cargo/remote:BUILD.rand_chacha-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rand_core__0_6_3",
        url = "https://crates.io/api/v1/crates/rand_core/0.6.3/download",
        type = "tar.gz",
        sha256 = "d34f1408f55294453790c48b2f1ebbb1c5b4b7563eb1f418bcfcfdbb06ebb4e7",
        strip_prefix = "rand_core-0.6.3",
        build_file = Label("//cargo/remote:BUILD.rand_core-0.6.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__redox_syscall__0_2_16",
        url = "https://crates.io/api/v1/crates/redox_syscall/0.2.16/download",
        type = "tar.gz",
        sha256 = "fb5a58c1855b4b6819d59012155603f0b22ad30cad752600aadfcb695265519a",
        strip_prefix = "redox_syscall-0.2.16",
        build_file = Label("//cargo/remote:BUILD.redox_syscall-0.2.16.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__redox_users__0_4_3",
        url = "https://crates.io/api/v1/crates/redox_users/0.4.3/download",
        type = "tar.gz",
        sha256 = "b033d837a7cf162d7993aded9304e30a83213c648b6e389db233191f891e5c2b",
        strip_prefix = "redox_users-0.4.3",
        build_file = Label("//cargo/remote:BUILD.redox_users-0.4.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__remove_dir_all__0_5_3",
        url = "https://crates.io/api/v1/crates/remove_dir_all/0.5.3/download",
        type = "tar.gz",
        sha256 = "3acd125665422973a33ac9d3dd2df85edad0f4ae9b00dafb1a05e43a9f5ef8e7",
        strip_prefix = "remove_dir_all-0.5.3",
        build_file = Label("//cargo/remote:BUILD.remove_dir_all-0.5.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ring__0_16_20",
        url = "https://crates.io/api/v1/crates/ring/0.16.20/download",
        type = "tar.gz",
        sha256 = "3053cf52e236a3ed746dfc745aa9cacf1b791d846bdaf412f60a8d7d6e17c8fc",
        strip_prefix = "ring-0.16.20",
        build_file = Label("//cargo/remote:BUILD.ring-0.16.20.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__rustls__0_19_1",
        url = "https://crates.io/api/v1/crates/rustls/0.19.1/download",
        type = "tar.gz",
        sha256 = "35edb675feee39aec9c99fa5ff985081995a06d594114ae14cbe797ad7b7a6d7",
        strip_prefix = "rustls-0.19.1",
        build_file = Label("//cargo/remote:BUILD.rustls-0.19.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__ryu__1_0_11",
        url = "https://crates.io/api/v1/crates/ryu/1.0.11/download",
        type = "tar.gz",
        sha256 = "4501abdff3ae82a1c1b477a17252eb69cee9e66eb915c1abaa4f44d873df9f09",
        strip_prefix = "ryu-1.0.11",
        build_file = Label("//cargo/remote:BUILD.ryu-1.0.11.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__safemem__0_3_3",
        url = "https://crates.io/api/v1/crates/safemem/0.3.3/download",
        type = "tar.gz",
        sha256 = "ef703b7cb59335eae2eb93ceb664c0eb7ea6bf567079d843e09420219668e072",
        strip_prefix = "safemem-0.3.3",
        build_file = Label("//cargo/remote:BUILD.safemem-0.3.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__schemars__0_8_10",
        url = "https://crates.io/api/v1/crates/schemars/0.8.10/download",
        type = "tar.gz",
        sha256 = "1847b767a3d62d95cbf3d8a9f0e421cf57a0d8aa4f411d4b16525afb0284d4ed",
        strip_prefix = "schemars-0.8.10",
        build_file = Label("//cargo/remote:BUILD.schemars-0.8.10.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__schemars_derive__0_8_10",
        url = "https://crates.io/api/v1/crates/schemars_derive/0.8.10/download",
        type = "tar.gz",
        sha256 = "af4d7e1b012cb3d9129567661a63755ea4b8a7386d339dc945ae187e403c6743",
        strip_prefix = "schemars_derive-0.8.10",
        build_file = Label("//cargo/remote:BUILD.schemars_derive-0.8.10.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__scoped_tls__1_0_0",
        url = "https://crates.io/api/v1/crates/scoped-tls/1.0.0/download",
        type = "tar.gz",
        sha256 = "ea6a9290e3c9cf0f18145ef7ffa62d68ee0bf5fcd651017e586dc7fd5da448c2",
        strip_prefix = "scoped-tls-1.0.0",
        build_file = Label("//cargo/remote:BUILD.scoped-tls-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__scopeguard__1_1_0",
        url = "https://crates.io/api/v1/crates/scopeguard/1.1.0/download",
        type = "tar.gz",
        sha256 = "d29ab0c6d3fc0ee92fe66e2d99f700eab17a8d57d1c1d3b748380fb20baa78cd",
        strip_prefix = "scopeguard-1.1.0",
        build_file = Label("//cargo/remote:BUILD.scopeguard-1.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__sct__0_6_1",
        url = "https://crates.io/api/v1/crates/sct/0.6.1/download",
        type = "tar.gz",
        sha256 = "b362b83898e0e69f38515b82ee15aa80636befe47c3b6d3d89a911e78fc228ce",
        strip_prefix = "sct-0.6.1",
        build_file = Label("//cargo/remote:BUILD.sct-0.6.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__secrecy__0_8_0",
        url = "https://crates.io/api/v1/crates/secrecy/0.8.0/download",
        type = "tar.gz",
        sha256 = "9bd1c54ea06cfd2f6b63219704de0b9b4f72dcc2b8fdef820be6cd799780e91e",
        strip_prefix = "secrecy-0.8.0",
        build_file = Label("//cargo/remote:BUILD.secrecy-0.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__serde__1_0_143",
        url = "https://crates.io/api/v1/crates/serde/1.0.143/download",
        type = "tar.gz",
        sha256 = "53e8e5d5b70924f74ff5c6d64d9a5acd91422117c60f48c4e07855238a254553",
        strip_prefix = "serde-1.0.143",
        build_file = Label("//cargo/remote:BUILD.serde-1.0.143.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__serde_value__0_7_0",
        url = "https://crates.io/api/v1/crates/serde-value/0.7.0/download",
        type = "tar.gz",
        sha256 = "f3a1a3341211875ef120e117ea7fd5228530ae7e7036a779fdc9117be6b3282c",
        strip_prefix = "serde-value-0.7.0",
        build_file = Label("//cargo/remote:BUILD.serde-value-0.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__serde_derive__1_0_143",
        url = "https://crates.io/api/v1/crates/serde_derive/1.0.143/download",
        type = "tar.gz",
        sha256 = "d3d8e8de557aee63c26b85b947f5e59b690d0454c753f3adeb5cd7835ab88391",
        strip_prefix = "serde_derive-1.0.143",
        build_file = Label("//cargo/remote:BUILD.serde_derive-1.0.143.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__serde_derive_internals__0_26_0",
        url = "https://crates.io/api/v1/crates/serde_derive_internals/0.26.0/download",
        type = "tar.gz",
        sha256 = "85bf8229e7920a9f636479437026331ce11aa132b4dde37d121944a44d6e5f3c",
        strip_prefix = "serde_derive_internals-0.26.0",
        build_file = Label("//cargo/remote:BUILD.serde_derive_internals-0.26.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__serde_json__1_0_83",
        url = "https://crates.io/api/v1/crates/serde_json/1.0.83/download",
        type = "tar.gz",
        sha256 = "38dd04e3c8279e75b31ef29dbdceebfe5ad89f4d0937213c53f7d49d01b3d5a7",
        strip_prefix = "serde_json-1.0.83",
        build_file = Label("//cargo/remote:BUILD.serde_json-1.0.83.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__serde_urlencoded__0_7_1",
        url = "https://crates.io/api/v1/crates/serde_urlencoded/0.7.1/download",
        type = "tar.gz",
        sha256 = "d3491c14715ca2294c4d6a88f15e84739788c1d030eed8c110436aafdaa2f3fd",
        strip_prefix = "serde_urlencoded-0.7.1",
        build_file = Label("//cargo/remote:BUILD.serde_urlencoded-0.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__serde_yaml__0_8_26",
        url = "https://crates.io/api/v1/crates/serde_yaml/0.8.26/download",
        type = "tar.gz",
        sha256 = "578a7433b776b56a35785ed5ce9a7e777ac0598aac5a6dd1b4b18a307c7fc71b",
        strip_prefix = "serde_yaml-0.8.26",
        build_file = Label("//cargo/remote:BUILD.serde_yaml-0.8.26.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__serde_yaml__0_9_7",
        url = "https://crates.io/api/v1/crates/serde_yaml/0.9.7/download",
        type = "tar.gz",
        sha256 = "b391fc9613ba9d6837bd806b4bddb25cf6b35d1ed1ef8bd32d10d5e063d3279b",
        strip_prefix = "serde_yaml-0.9.7",
        build_file = Label("//cargo/remote:BUILD.serde_yaml-0.9.7.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__sha_1__0_10_0",
        url = "https://crates.io/api/v1/crates/sha-1/0.10.0/download",
        type = "tar.gz",
        sha256 = "028f48d513f9678cda28f6e4064755b3fbb2af6acd672f2c209b62323f7aea0f",
        strip_prefix = "sha-1-0.10.0",
        build_file = Label("//cargo/remote:BUILD.sha-1-0.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__sha_1__0_9_8",
        url = "https://crates.io/api/v1/crates/sha-1/0.9.8/download",
        type = "tar.gz",
        sha256 = "99cd6713db3cf16b6c84e06321e049a9b9f699826e16096d23bbcc44d15d51a6",
        strip_prefix = "sha-1-0.9.8",
        build_file = Label("//cargo/remote:BUILD.sha-1-0.9.8.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__sharded_slab__0_1_4",
        url = "https://crates.io/api/v1/crates/sharded-slab/0.1.4/download",
        type = "tar.gz",
        sha256 = "900fba806f70c630b0a382d0d825e17a0f19fcd059a2ade1ff237bcddf446b31",
        strip_prefix = "sharded-slab-0.1.4",
        build_file = Label("//cargo/remote:BUILD.sharded-slab-0.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__signal_hook_registry__1_4_0",
        url = "https://crates.io/api/v1/crates/signal-hook-registry/1.4.0/download",
        type = "tar.gz",
        sha256 = "e51e73328dc4ac0c7ccbda3a494dfa03df1de2f46018127f60c693f2648455b0",
        strip_prefix = "signal-hook-registry-1.4.0",
        build_file = Label("//cargo/remote:BUILD.signal-hook-registry-1.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__slab__0_4_7",
        url = "https://crates.io/api/v1/crates/slab/0.4.7/download",
        type = "tar.gz",
        sha256 = "4614a76b2a8be0058caa9dbbaf66d988527d86d003c11a94fbd335d7661edcef",
        strip_prefix = "slab-0.4.7",
        build_file = Label("//cargo/remote:BUILD.slab-0.4.7.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__smallvec__1_9_0",
        url = "https://crates.io/api/v1/crates/smallvec/1.9.0/download",
        type = "tar.gz",
        sha256 = "2fd0db749597d91ff862fd1d55ea87f7855a744a8425a64695b6fca237d1dad1",
        strip_prefix = "smallvec-1.9.0",
        build_file = Label("//cargo/remote:BUILD.smallvec-1.9.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__socket2__0_4_4",
        url = "https://crates.io/api/v1/crates/socket2/0.4.4/download",
        type = "tar.gz",
        sha256 = "66d72b759436ae32898a2af0a14218dbf55efde3feeb170eb623637db85ee1e0",
        strip_prefix = "socket2-0.4.4",
        build_file = Label("//cargo/remote:BUILD.socket2-0.4.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__spin__0_5_2",
        url = "https://crates.io/api/v1/crates/spin/0.5.2/download",
        type = "tar.gz",
        sha256 = "6e63cff320ae2c57904679ba7cb63280a3dc4613885beafb148ee7bf9aa9042d",
        strip_prefix = "spin-0.5.2",
        build_file = Label("//cargo/remote:BUILD.spin-0.5.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__strsim__0_10_0",
        url = "https://crates.io/api/v1/crates/strsim/0.10.0/download",
        type = "tar.gz",
        sha256 = "73473c0e59e6d5812c5dfe2a064a6444949f089e20eec9a2e5506596494e4623",
        strip_prefix = "strsim-0.10.0",
        build_file = Label("//cargo/remote:BUILD.strsim-0.10.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__syn__1_0_99",
        url = "https://crates.io/api/v1/crates/syn/1.0.99/download",
        type = "tar.gz",
        sha256 = "58dbef6ec655055e20b86b15a8cc6d439cca19b667537ac6a1369572d151ab13",
        strip_prefix = "syn-1.0.99",
        build_file = Label("//cargo/remote:BUILD.syn-1.0.99.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tempfile__3_3_0",
        url = "https://crates.io/api/v1/crates/tempfile/3.3.0/download",
        type = "tar.gz",
        sha256 = "5cdb1ef4eaeeaddc8fbd371e5017057064af0911902ef36b39801f67cc6d79e4",
        strip_prefix = "tempfile-3.3.0",
        build_file = Label("//cargo/remote:BUILD.tempfile-3.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__termcolor__1_1_3",
        url = "https://crates.io/api/v1/crates/termcolor/1.1.3/download",
        type = "tar.gz",
        sha256 = "bab24d30b911b2376f3a13cc2cd443142f0c81dda04c118693e35b3835757755",
        strip_prefix = "termcolor-1.1.3",
        build_file = Label("//cargo/remote:BUILD.termcolor-1.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__textwrap__0_15_0",
        url = "https://crates.io/api/v1/crates/textwrap/0.15.0/download",
        type = "tar.gz",
        sha256 = "b1141d4d61095b28419e22cb0bbf02755f5e54e0526f97f1e3d1d160e60885fb",
        strip_prefix = "textwrap-0.15.0",
        build_file = Label("//cargo/remote:BUILD.textwrap-0.15.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__thiserror__1_0_32",
        url = "https://crates.io/api/v1/crates/thiserror/1.0.32/download",
        type = "tar.gz",
        sha256 = "f5f6586b7f764adc0231f4c79be7b920e766bb2f3e51b3661cdb263828f19994",
        strip_prefix = "thiserror-1.0.32",
        build_file = Label("//cargo/remote:BUILD.thiserror-1.0.32.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__thiserror_impl__1_0_32",
        url = "https://crates.io/api/v1/crates/thiserror-impl/1.0.32/download",
        type = "tar.gz",
        sha256 = "12bafc5b54507e0149cdf1b145a5d80ab80a90bcd9275df43d4fff68460f6c21",
        strip_prefix = "thiserror-impl-1.0.32",
        build_file = Label("//cargo/remote:BUILD.thiserror-impl-1.0.32.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__thread_local__1_1_4",
        url = "https://crates.io/api/v1/crates/thread_local/1.1.4/download",
        type = "tar.gz",
        sha256 = "5516c27b78311c50bf42c071425c560ac799b11c30b31f87e3081965fe5e0180",
        strip_prefix = "thread_local-1.1.4",
        build_file = Label("//cargo/remote:BUILD.thread_local-1.1.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tinyvec__1_6_0",
        url = "https://crates.io/api/v1/crates/tinyvec/1.6.0/download",
        type = "tar.gz",
        sha256 = "87cc5ceb3875bb20c2890005a4e226a4651264a5c75edb2421b52861a0a0cb50",
        strip_prefix = "tinyvec-1.6.0",
        build_file = Label("//cargo/remote:BUILD.tinyvec-1.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tinyvec_macros__0_1_0",
        url = "https://crates.io/api/v1/crates/tinyvec_macros/0.1.0/download",
        type = "tar.gz",
        sha256 = "cda74da7e1a664f795bb1f8a87ec406fb89a02522cf6e50620d016add6dbbf5c",
        strip_prefix = "tinyvec_macros-0.1.0",
        build_file = Label("//cargo/remote:BUILD.tinyvec_macros-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tokio__1_20_1",
        url = "https://crates.io/api/v1/crates/tokio/1.20.1/download",
        type = "tar.gz",
        sha256 = "7a8325f63a7d4774dd041e363b2409ed1c5cbbd0f867795e661df066b2b0a581",
        strip_prefix = "tokio-1.20.1",
        build_file = Label("//cargo/remote:BUILD.tokio-1.20.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tokio_io_timeout__1_2_0",
        url = "https://crates.io/api/v1/crates/tokio-io-timeout/1.2.0/download",
        type = "tar.gz",
        sha256 = "30b74022ada614a1b4834de765f9bb43877f910cc8ce4be40e89042c9223a8bf",
        strip_prefix = "tokio-io-timeout-1.2.0",
        build_file = Label("//cargo/remote:BUILD.tokio-io-timeout-1.2.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tokio_macros__1_8_0",
        url = "https://crates.io/api/v1/crates/tokio-macros/1.8.0/download",
        type = "tar.gz",
        sha256 = "9724f9a975fb987ef7a3cd9be0350edcbe130698af5b8f7a631e23d42d052484",
        strip_prefix = "tokio-macros-1.8.0",
        build_file = Label("//cargo/remote:BUILD.tokio-macros-1.8.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tokio_openssl__0_6_3",
        url = "https://crates.io/api/v1/crates/tokio-openssl/0.6.3/download",
        type = "tar.gz",
        sha256 = "c08f9ffb7809f1b20c1b398d92acf4cc719874b3b2b2d9ea2f09b4a80350878a",
        strip_prefix = "tokio-openssl-0.6.3",
        build_file = Label("//cargo/remote:BUILD.tokio-openssl-0.6.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tokio_rustls__0_22_0",
        url = "https://crates.io/api/v1/crates/tokio-rustls/0.22.0/download",
        type = "tar.gz",
        sha256 = "bc6844de72e57df1980054b38be3a9f4702aba4858be64dd700181a8a6d0e1b6",
        strip_prefix = "tokio-rustls-0.22.0",
        build_file = Label("//cargo/remote:BUILD.tokio-rustls-0.22.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tokio_stream__0_1_9",
        url = "https://crates.io/api/v1/crates/tokio-stream/0.1.9/download",
        type = "tar.gz",
        sha256 = "df54d54117d6fdc4e4fea40fe1e4e566b3505700e148a6827e59b34b0d2600d9",
        strip_prefix = "tokio-stream-0.1.9",
        build_file = Label("//cargo/remote:BUILD.tokio-stream-0.1.9.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tokio_tungstenite__0_15_0",
        url = "https://crates.io/api/v1/crates/tokio-tungstenite/0.15.0/download",
        type = "tar.gz",
        sha256 = "511de3f85caf1c98983545490c3d09685fa8eb634e57eec22bb4db271f46cbd8",
        strip_prefix = "tokio-tungstenite-0.15.0",
        build_file = Label("//cargo/remote:BUILD.tokio-tungstenite-0.15.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tokio_util__0_6_10",
        url = "https://crates.io/api/v1/crates/tokio-util/0.6.10/download",
        type = "tar.gz",
        sha256 = "36943ee01a6d67977dd3f84a5a1d2efeb4ada3a1ae771cadfaa535d9d9fc6507",
        strip_prefix = "tokio-util-0.6.10",
        build_file = Label("//cargo/remote:BUILD.tokio-util-0.6.10.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tokio_util__0_7_3",
        url = "https://crates.io/api/v1/crates/tokio-util/0.7.3/download",
        type = "tar.gz",
        sha256 = "cc463cd8deddc3770d20f9852143d50bf6094e640b485cb2e189a2099085ff45",
        strip_prefix = "tokio-util-0.7.3",
        build_file = Label("//cargo/remote:BUILD.tokio-util-0.7.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tower__0_4_13",
        url = "https://crates.io/api/v1/crates/tower/0.4.13/download",
        type = "tar.gz",
        sha256 = "b8fa9be0de6cf49e536ce1851f987bd21a43b771b09473c3549a6c853db37c1c",
        strip_prefix = "tower-0.4.13",
        build_file = Label("//cargo/remote:BUILD.tower-0.4.13.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tower_http__0_3_4",
        url = "https://crates.io/api/v1/crates/tower-http/0.3.4/download",
        type = "tar.gz",
        sha256 = "3c530c8675c1dbf98facee631536fa116b5fb6382d7dd6dc1b118d970eafe3ba",
        strip_prefix = "tower-http-0.3.4",
        build_file = Label("//cargo/remote:BUILD.tower-http-0.3.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tower_layer__0_3_1",
        url = "https://crates.io/api/v1/crates/tower-layer/0.3.1/download",
        type = "tar.gz",
        sha256 = "343bc9466d3fe6b0f960ef45960509f84480bf4fd96f92901afe7ff3df9d3a62",
        strip_prefix = "tower-layer-0.3.1",
        build_file = Label("//cargo/remote:BUILD.tower-layer-0.3.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tower_service__0_3_2",
        url = "https://crates.io/api/v1/crates/tower-service/0.3.2/download",
        type = "tar.gz",
        sha256 = "b6bc1c9ce2b5135ac7f93c72918fc37feb872bdc6a5533a8b85eb4b86bfdae52",
        strip_prefix = "tower-service-0.3.2",
        build_file = Label("//cargo/remote:BUILD.tower-service-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tracing__0_1_36",
        url = "https://crates.io/api/v1/crates/tracing/0.1.36/download",
        type = "tar.gz",
        sha256 = "2fce9567bd60a67d08a16488756721ba392f24f29006402881e43b19aac64307",
        strip_prefix = "tracing-0.1.36",
        build_file = Label("//cargo/remote:BUILD.tracing-0.1.36.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tracing_attributes__0_1_22",
        url = "https://crates.io/api/v1/crates/tracing-attributes/0.1.22/download",
        type = "tar.gz",
        sha256 = "11c75893af559bc8e10716548bdef5cb2b983f8e637db9d0e15126b61b484ee2",
        strip_prefix = "tracing-attributes-0.1.22",
        build_file = Label("//cargo/remote:BUILD.tracing-attributes-0.1.22.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tracing_core__0_1_29",
        url = "https://crates.io/api/v1/crates/tracing-core/0.1.29/download",
        type = "tar.gz",
        sha256 = "5aeea4303076558a00714b823f9ad67d58a3bbda1df83d8827d21193156e22f7",
        strip_prefix = "tracing-core-0.1.29",
        build_file = Label("//cargo/remote:BUILD.tracing-core-0.1.29.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tracing_log__0_1_3",
        url = "https://crates.io/api/v1/crates/tracing-log/0.1.3/download",
        type = "tar.gz",
        sha256 = "78ddad33d2d10b1ed7eb9d1f518a5674713876e97e5bb9b7345a7984fbb4f922",
        strip_prefix = "tracing-log-0.1.3",
        build_file = Label("//cargo/remote:BUILD.tracing-log-0.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tracing_subscriber__0_3_15",
        url = "https://crates.io/api/v1/crates/tracing-subscriber/0.3.15/download",
        type = "tar.gz",
        sha256 = "60db860322da191b40952ad9affe65ea23e7dd6a5c442c2c42865810c6ab8e6b",
        strip_prefix = "tracing-subscriber-0.3.15",
        build_file = Label("//cargo/remote:BUILD.tracing-subscriber-0.3.15.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__treediff__3_0_2",
        url = "https://crates.io/api/v1/crates/treediff/3.0.2/download",
        type = "tar.gz",
        sha256 = "761e8d5ad7ce14bb82b7e61ccc0ca961005a275a060b9644a2431aa11553c2ff",
        strip_prefix = "treediff-3.0.2",
        build_file = Label("//cargo/remote:BUILD.treediff-3.0.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__try_lock__0_2_3",
        url = "https://crates.io/api/v1/crates/try-lock/0.2.3/download",
        type = "tar.gz",
        sha256 = "59547bce71d9c38b83d9c0e92b6066c4253371f15005def0c30d9657f50c7642",
        strip_prefix = "try-lock-0.2.3",
        build_file = Label("//cargo/remote:BUILD.try-lock-0.2.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__tungstenite__0_14_0",
        url = "https://crates.io/api/v1/crates/tungstenite/0.14.0/download",
        type = "tar.gz",
        sha256 = "a0b2d8558abd2e276b0a8df5c05a2ec762609344191e5fd23e292c910e9165b5",
        strip_prefix = "tungstenite-0.14.0",
        build_file = Label("//cargo/remote:BUILD.tungstenite-0.14.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__twoway__0_1_8",
        url = "https://crates.io/api/v1/crates/twoway/0.1.8/download",
        type = "tar.gz",
        sha256 = "59b11b2b5241ba34be09c3cc85a36e56e48f9888862e19cedf23336d35316ed1",
        strip_prefix = "twoway-0.1.8",
        build_file = Label("//cargo/remote:BUILD.twoway-0.1.8.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__typenum__1_15_0",
        url = "https://crates.io/api/v1/crates/typenum/1.15.0/download",
        type = "tar.gz",
        sha256 = "dcf81ac59edc17cc8697ff311e8f5ef2d99fcbd9817b34cec66f90b6c3dfd987",
        strip_prefix = "typenum-1.15.0",
        build_file = Label("//cargo/remote:BUILD.typenum-1.15.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__unicase__2_6_0",
        url = "https://crates.io/api/v1/crates/unicase/2.6.0/download",
        type = "tar.gz",
        sha256 = "50f37be617794602aabbeee0be4f259dc1778fabe05e2d67ee8f79326d5cb4f6",
        strip_prefix = "unicase-2.6.0",
        build_file = Label("//cargo/remote:BUILD.unicase-2.6.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__unicode_bidi__0_3_8",
        url = "https://crates.io/api/v1/crates/unicode-bidi/0.3.8/download",
        type = "tar.gz",
        sha256 = "099b7128301d285f79ddd55b9a83d5e6b9e97c92e0ea0daebee7263e932de992",
        strip_prefix = "unicode-bidi-0.3.8",
        build_file = Label("//cargo/remote:BUILD.unicode-bidi-0.3.8.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__unicode_ident__1_0_3",
        url = "https://crates.io/api/v1/crates/unicode-ident/1.0.3/download",
        type = "tar.gz",
        sha256 = "c4f5b37a154999a8f3f98cc23a628d850e154479cd94decf3414696e12e31aaf",
        strip_prefix = "unicode-ident-1.0.3",
        build_file = Label("//cargo/remote:BUILD.unicode-ident-1.0.3.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__unicode_normalization__0_1_21",
        url = "https://crates.io/api/v1/crates/unicode-normalization/0.1.21/download",
        type = "tar.gz",
        sha256 = "854cbdc4f7bc6ae19c820d44abdc3277ac3e1b2b93db20a636825d9322fb60e6",
        strip_prefix = "unicode-normalization-0.1.21",
        build_file = Label("//cargo/remote:BUILD.unicode-normalization-0.1.21.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__unsafe_libyaml__0_2_2",
        url = "https://crates.io/api/v1/crates/unsafe-libyaml/0.2.2/download",
        type = "tar.gz",
        sha256 = "931179334a56395bcf64ba5e0ff56781381c1a5832178280c7d7f91d1679aeb0",
        strip_prefix = "unsafe-libyaml-0.2.2",
        build_file = Label("//cargo/remote:BUILD.unsafe-libyaml-0.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__untrusted__0_7_1",
        url = "https://crates.io/api/v1/crates/untrusted/0.7.1/download",
        type = "tar.gz",
        sha256 = "a156c684c91ea7d62626509bce3cb4e1d9ed5c4d978f7b4352658f96a4c26b4a",
        strip_prefix = "untrusted-0.7.1",
        build_file = Label("//cargo/remote:BUILD.untrusted-0.7.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__url__2_2_2",
        url = "https://crates.io/api/v1/crates/url/2.2.2/download",
        type = "tar.gz",
        sha256 = "a507c383b2d33b5fc35d1861e77e6b383d158b2da5e14fe51b83dfedf6fd578c",
        strip_prefix = "url-2.2.2",
        build_file = Label("//cargo/remote:BUILD.url-2.2.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__utf_8__0_7_6",
        url = "https://crates.io/api/v1/crates/utf-8/0.7.6/download",
        type = "tar.gz",
        sha256 = "09cc8ee72d2a9becf2f2febe0205bbed8fc6615b7cb429ad062dc7b7ddd036a9",
        strip_prefix = "utf-8-0.7.6",
        build_file = Label("//cargo/remote:BUILD.utf-8-0.7.6.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__valuable__0_1_0",
        url = "https://crates.io/api/v1/crates/valuable/0.1.0/download",
        type = "tar.gz",
        sha256 = "830b7e5d4d90034032940e4ace0d9a9a057e7a45cd94e6c007832e39edb82f6d",
        strip_prefix = "valuable-0.1.0",
        build_file = Label("//cargo/remote:BUILD.valuable-0.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__vcpkg__0_2_15",
        url = "https://crates.io/api/v1/crates/vcpkg/0.2.15/download",
        type = "tar.gz",
        sha256 = "accd4ea62f7bb7a82fe23066fb0957d48ef677f6eeb8215f372f52e48bb32426",
        strip_prefix = "vcpkg-0.2.15",
        build_file = Label("//cargo/remote:BUILD.vcpkg-0.2.15.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__version_check__0_9_4",
        url = "https://crates.io/api/v1/crates/version_check/0.9.4/download",
        type = "tar.gz",
        sha256 = "49874b5167b65d7193b8aba1567f5c7d93d001cafc34600cee003eda787e483f",
        strip_prefix = "version_check-0.9.4",
        build_file = Label("//cargo/remote:BUILD.version_check-0.9.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__want__0_3_0",
        url = "https://crates.io/api/v1/crates/want/0.3.0/download",
        type = "tar.gz",
        sha256 = "1ce8a968cb1cd110d136ff8b819a556d6fb6d919363c61534f6860c7eb172ba0",
        strip_prefix = "want-0.3.0",
        build_file = Label("//cargo/remote:BUILD.want-0.3.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__warp__0_3_2",
        url = "https://crates.io/api/v1/crates/warp/0.3.2/download",
        type = "tar.gz",
        sha256 = "3cef4e1e9114a4b7f1ac799f16ce71c14de5778500c5450ec6b7b920c55b587e",
        strip_prefix = "warp-0.3.2",
        build_file = Label("//cargo/remote:BUILD.warp-0.3.2.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__wasi__0_11_0_wasi_snapshot_preview1",
        url = "https://crates.io/api/v1/crates/wasi/0.11.0+wasi-snapshot-preview1/download",
        type = "tar.gz",
        sha256 = "9c8d87e72b64a3b4db28d11ce29237c246188f4f51057d65a7eab63b7987e423",
        strip_prefix = "wasi-0.11.0+wasi-snapshot-preview1",
        build_file = Label("//cargo/remote:BUILD.wasi-0.11.0+wasi-snapshot-preview1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__wasm_bindgen__0_2_82",
        url = "https://crates.io/api/v1/crates/wasm-bindgen/0.2.82/download",
        type = "tar.gz",
        sha256 = "fc7652e3f6c4706c8d9cd54832c4a4ccb9b5336e2c3bd154d5cccfbf1c1f5f7d",
        strip_prefix = "wasm-bindgen-0.2.82",
        build_file = Label("//cargo/remote:BUILD.wasm-bindgen-0.2.82.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__wasm_bindgen_backend__0_2_82",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-backend/0.2.82/download",
        type = "tar.gz",
        sha256 = "662cd44805586bd52971b9586b1df85cdbbd9112e4ef4d8f41559c334dc6ac3f",
        strip_prefix = "wasm-bindgen-backend-0.2.82",
        build_file = Label("//cargo/remote:BUILD.wasm-bindgen-backend-0.2.82.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__wasm_bindgen_macro__0_2_82",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro/0.2.82/download",
        type = "tar.gz",
        sha256 = "b260f13d3012071dfb1512849c033b1925038373aea48ced3012c09df952c602",
        strip_prefix = "wasm-bindgen-macro-0.2.82",
        build_file = Label("//cargo/remote:BUILD.wasm-bindgen-macro-0.2.82.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__wasm_bindgen_macro_support__0_2_82",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-macro-support/0.2.82/download",
        type = "tar.gz",
        sha256 = "5be8e654bdd9b79216c2929ab90721aa82faf65c48cdf08bdc4e7f51357b80da",
        strip_prefix = "wasm-bindgen-macro-support-0.2.82",
        build_file = Label("//cargo/remote:BUILD.wasm-bindgen-macro-support-0.2.82.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__wasm_bindgen_shared__0_2_82",
        url = "https://crates.io/api/v1/crates/wasm-bindgen-shared/0.2.82/download",
        type = "tar.gz",
        sha256 = "6598dd0bd3c7d51095ff6531a5b23e02acdc81804e30d8f07afb77b7215a140a",
        strip_prefix = "wasm-bindgen-shared-0.2.82",
        build_file = Label("//cargo/remote:BUILD.wasm-bindgen-shared-0.2.82.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__web_sys__0_3_59",
        url = "https://crates.io/api/v1/crates/web-sys/0.3.59/download",
        type = "tar.gz",
        sha256 = "ed055ab27f941423197eb86b2035720b1a3ce40504df082cac2ecc6ed73335a1",
        strip_prefix = "web-sys-0.3.59",
        build_file = Label("//cargo/remote:BUILD.web-sys-0.3.59.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__webpki__0_21_4",
        url = "https://crates.io/api/v1/crates/webpki/0.21.4/download",
        type = "tar.gz",
        sha256 = "b8e38c0608262c46d4a56202ebabdeb094cef7e560ca7a226c6bf055188aa4ea",
        strip_prefix = "webpki-0.21.4",
        build_file = Label("//cargo/remote:BUILD.webpki-0.21.4.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__winapi__0_3_9",
        url = "https://crates.io/api/v1/crates/winapi/0.3.9/download",
        type = "tar.gz",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        strip_prefix = "winapi-0.3.9",
        build_file = Label("//cargo/remote:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__winapi_i686_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("//cargo/remote:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__winapi_util__0_1_5",
        url = "https://crates.io/api/v1/crates/winapi-util/0.1.5/download",
        type = "tar.gz",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("//cargo/remote:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__winapi_x86_64_pc_windows_gnu__0_4_0",
        url = "https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download",
        type = "tar.gz",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("//cargo/remote:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__windows_sys__0_36_1",
        url = "https://crates.io/api/v1/crates/windows-sys/0.36.1/download",
        type = "tar.gz",
        sha256 = "ea04155a16a59f9eab786fe12a4a450e75cdb175f9e0d80da1e17db09f55b8d2",
        strip_prefix = "windows-sys-0.36.1",
        build_file = Label("//cargo/remote:BUILD.windows-sys-0.36.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__windows_aarch64_msvc__0_36_1",
        url = "https://crates.io/api/v1/crates/windows_aarch64_msvc/0.36.1/download",
        type = "tar.gz",
        sha256 = "9bb8c3fd39ade2d67e9874ac4f3db21f0d710bee00fe7cab16949ec184eeaa47",
        strip_prefix = "windows_aarch64_msvc-0.36.1",
        build_file = Label("//cargo/remote:BUILD.windows_aarch64_msvc-0.36.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__windows_i686_gnu__0_36_1",
        url = "https://crates.io/api/v1/crates/windows_i686_gnu/0.36.1/download",
        type = "tar.gz",
        sha256 = "180e6ccf01daf4c426b846dfc66db1fc518f074baa793aa7d9b9aaeffad6a3b6",
        strip_prefix = "windows_i686_gnu-0.36.1",
        build_file = Label("//cargo/remote:BUILD.windows_i686_gnu-0.36.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__windows_i686_msvc__0_36_1",
        url = "https://crates.io/api/v1/crates/windows_i686_msvc/0.36.1/download",
        type = "tar.gz",
        sha256 = "e2e7917148b2812d1eeafaeb22a97e4813dfa60a3f8f78ebe204bcc88f12f024",
        strip_prefix = "windows_i686_msvc-0.36.1",
        build_file = Label("//cargo/remote:BUILD.windows_i686_msvc-0.36.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__windows_x86_64_gnu__0_36_1",
        url = "https://crates.io/api/v1/crates/windows_x86_64_gnu/0.36.1/download",
        type = "tar.gz",
        sha256 = "4dcd171b8776c41b97521e5da127a2d86ad280114807d0b2ab1e462bc764d9e1",
        strip_prefix = "windows_x86_64_gnu-0.36.1",
        build_file = Label("//cargo/remote:BUILD.windows_x86_64_gnu-0.36.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__windows_x86_64_msvc__0_36_1",
        url = "https://crates.io/api/v1/crates/windows_x86_64_msvc/0.36.1/download",
        type = "tar.gz",
        sha256 = "c811ca4a8c853ef420abd8592ba53ddbbac90410fab6903b3e79972a631f7680",
        strip_prefix = "windows_x86_64_msvc-0.36.1",
        build_file = Label("//cargo/remote:BUILD.windows_x86_64_msvc-0.36.1.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__yaml_rust__0_4_5",
        url = "https://crates.io/api/v1/crates/yaml-rust/0.4.5/download",
        type = "tar.gz",
        sha256 = "56c1936c4cc7a1c9ab21a1ebb602eb942ba868cbd44a99cb7cdc5892335e1c85",
        strip_prefix = "yaml-rust-0.4.5",
        build_file = Label("//cargo/remote:BUILD.yaml-rust-0.4.5.bazel"),
    )

    maybe(
        http_archive,
        name = "raze__zeroize__1_5_7",
        url = "https://crates.io/api/v1/crates/zeroize/1.5.7/download",
        type = "tar.gz",
        sha256 = "c394b5bd0c6f669e7275d9c20aa90ae064cb22e75a1cad54e1b34088034b149f",
        strip_prefix = "zeroize-1.5.7",
        build_file = Label("//cargo/remote:BUILD.zeroize-1.5.7.bazel"),
    )
