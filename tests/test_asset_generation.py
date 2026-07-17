from pathlib import Path

from tools import generate_textures


def test_texture_generation_preserves_replaced_branding(
    tmp_path: Path, monkeypatch
) -> None:
    branding = tmp_path / "branding"
    textures = tmp_path / "textures"
    branding.mkdir()
    replacement = branding / "recruitment_qr.png"
    replacement.write_bytes(b"event-owned-qr")
    monkeypatch.setattr(generate_textures, "BRANDING", branding)
    monkeypatch.setattr(generate_textures, "TEXTURES", textures)

    generate_textures.main([])

    assert replacement.read_bytes() == b"event-owned-qr"
    assert (branding / "game_logo.png").is_file()
    assert (textures / "web_grid.png").is_file()

