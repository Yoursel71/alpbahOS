from pathlib import Path


REPO = Path(__file__).resolve().parents[1]


def test_pipewire_candidate_build_keeps_required_audio_features_and_skips_missing_flatpak_glib():
    source = (REPO / "scripts/build-blfs-pipewire.sh").read_text(encoding="utf-8")
    for option in (
        "-D flatpak=disabled",
        "-D alsa=enabled",
        "-D sndfile=enabled",
        "-D pw-cat=enabled",
        "-D session-managers='[]'",
    ):
        assert option in source
