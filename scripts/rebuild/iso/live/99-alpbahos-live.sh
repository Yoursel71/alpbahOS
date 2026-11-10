# alpbahOS BETA live image only (test setting). The QEMU virtio GPU has no virgl, so Mesa uses software GL.
# Removed from the installed system by target-cleanup.sh.
export LIBGL_ALWAYS_SOFTWARE=1
