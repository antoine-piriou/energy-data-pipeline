import pytest

from energy_pipeline.config import get_db_settings


def test_missing_db_password_raises_clear_error(monkeypatch):
    # 1. retirer le mot de passe
    monkeypatch.delenv("POSTGRES_PASSWORD", raising=False)
    # 2. poser une valeur reconnaissable dans une autre variable (ex. POSTGRES_USER)
    monkeypatch.setenv("POSTGRES_USER", "fake_user")
    # 3. appeler get_db_settings() dans un pytest.raises, garder excinfo
    with pytest.raises(RuntimeError) as excinfo:
        get_db_settings()
    message = str(excinfo.value)
    # 4. vérifier que le nom de la variable est dans le message
    assert "POSTGRES_PASSWORD" in message
    # 5. vérifier que ta valeur reconnaissable n'y est pas
    assert "fake_user" not in message
