fn main() {
    let ver = env!("CARGO_PKG_VERSION").split(".").map(|x| x.parse::<u64>().unwrap()).collect::<Vec<u64>>();
    let sem_ver = ver[0] << 48 | ver[1] << 32 | ver[1] << 16;

    winres::WindowsResource::new()
        .set_version_info(winres::VersionInfo::PRODUCTVERSION, sem_ver)
        .compile()
        .unwrap();
}