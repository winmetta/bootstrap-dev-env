# Linux platform: not supported yet. Implements the platform contract described in
# platforms/README.md so the entry point fails early with a clear message.

platform_check() {
	log_step "Checking platform"
	die "Linux is not supported yet. See platforms/README.md for what a platform file has to provide."
}
