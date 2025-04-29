-- Fonction
CREATE OR REPLACE FUNCTION controle_temps() 
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OPNAME = ’UPDATE’ THEN

    IF NEW.jour < OLD.jour THEN RAISE EXCEPTION ’Impossible’;
    ELSIF NEW.jour = OLD.jour AND NEW.heure < OLD.heure THEN 
      RAISE EXCEPTION ’Impossible’;
    END IF;
    ELSIF TG_OPNAME = ’INSERT’ THEN
    IF (SELECT COUNT(*) FROM TEMPS) > 0 THEN RAISE EXCEPTION ’Impossible’;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Fonction pour insérer un nouvel utilisateur
CREATE OR REPLACE FUNCTION inserer_utilisateur(
    email VARCHAR(255),
    nom VARCHAR(64),
    prenom VARCHAR(64),
    statut VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    nb_max_billets INT;
BEGIN
    -- Vérification du statut
    IF statut NOT IN ('Normal', 'VIP', 'VVIP') THEN
        RAISE EXCEPTION 'Statut invalide : %', statut;
    END IF;

    -- Modification du nombre maximum de billets en fonction du statut
    IF statut = 'Normal' THEN
        nb_max_billets := 5;
    ELSIF statut = 'VIP' THEN
        nb_max_billets := 10;
    ELSIF statut = 'VVIP' THEN
        nb_max_billets := 20;
    END IF;

    -- Vérification du nombre maximum de billets
    IF nb_max_billets <= 0 THEN
        RAISE EXCEPTION 'Le nombre maximum de billets doit être supérieur à 0';
    END IF;

    -- Insertion dans la table Utilisateur
    INSERT INTO Utilisateur (Uemail, Unom, Uprenom, Ustatut, Unb_max_billets)
    VALUES (email, nom, prenom, statut, nb_max_billets);
END;
$$ LANGUAGE plpgsql;