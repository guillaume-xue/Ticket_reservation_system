CREATE OR REPLACE FUNCTION controle_temps() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OPNAME = UPDATE THEN
        IF NEW.jour < OLD.jour THEN 
            RAISE EXCEPTION 'Impossible';
        ELSIF NEW.jour = OLD.jour AND NEW.heure < OLD.heure THEN 
            RAISE EXCEPTION 'Impossible';
        END IF;
        ELSIF TG_OPNAME = INSERT THEN
            IF (SELECT COUNT(*) FROM TEMPS) > 0 THEN 
                RAISE EXCEPTION 'Impossible';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to control the insertion and update of the TEMPS table
CREATE TRIGGER controle_temps_trigger BEFORE UPDATE OR INSERT ON TEMPS
FOR EACH ROW
EXECUTE PROCEDURE controle_temps();

-- Fonction de trigger pour calculer automatiquement Unb_max_billets
CREATE OR REPLACE FUNCTION calcul_nb_max_billets()
RETURNS TRIGGER AS $$
BEGIN
    -- Vérification du statut
    IF NEW.Ustatut NOT IN ('Normal', 'VIP', 'VVIP') THEN
        RAISE EXCEPTION 'Statut invalide : %', NEW.Ustatut;
    END IF;

    -- Calcul du nombre maximum de billets
    IF NEW.Ustatut = 'Normal' THEN
        NEW.Unb_max_billets := 5;
    ELSIF NEW.Ustatut = 'VIP' THEN
        NEW.Unb_max_billets := 10;
    ELSIF NEW.Ustatut = 'VVIP' THEN
        NEW.Unb_max_billets := 20;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger avant insertion sur Utilisateur
CREATE TRIGGER calcul_nb_max_billets_trigger
BEFORE INSERT ON Utilisateur
FOR EACH ROW
EXECUTE PROCEDURE calcul_nb_max_billets();

-- Fonction pour insérer un nouvel événement
CREATE OR REPLACE FUNCTION inserer_evenement(
    id TEXT,
    nom VARCHAR(255),
    jour_debut INTEGER,
    heure_debut INTEGER,
    jour_fin INTEGER,
    heure_fin INTEGER,
    num_salle INT,
    description TEXT,
    type_evenement VARCHAR(32)
)
RETURNS VOID AS $$
BEGIN
    -- Vérification du type d'événement
    IF type_evenement NOT IN ('Concert', 'SousEvenement', 'Film') THEN
        RAISE EXCEPTION 'Type d''événement invalide : %', type_evenement;
    END IF;

    -- Insertion dans la table Evenement
    INSERT INTO Evenement (Eid, Enom, Edate, Enum_salle, Edescription, Etype)
    VALUES (id, nom, date, num_salle, description, type_evenement);
END;
$$ LANGUAGE plpgsql;

-- Incrementation de l'ID de billet
CREATE SEQUENCE billet_seq START 1;

-- Fonction pour générer un ID de billet unique
CREATE FUNCTION generer_id_billet() RETURNS TEXT AS $$
DECLARE
  numero INT;
BEGIN
  numero := nextval('billet_seq');
  RETURN 'BIL-' || TO_CHAR(CURRENT_DATE, 'YYYYMMDD') || '-' || LPAD(numero::text, 5, '0');
END;
$$ LANGUAGE plpgsql;

-- Fonction pour insérer un nouveau billet
CREATE OR REPLACE FUNCTION creer_billet(
    prix_initial DECIMAL(10, 2)
)
RETURNS VOID AS $$
DECLARE
    id_billet TEXT;
BEGIN
    -- Génération de l'ID du billet
    id_billet := generer_id_billet();

    -- Insertion dans la table Billet
    INSERT INTO Billet (Bid, Bdate_achat, Bprix_initial, Bprix_achat, Bpromotion, Bdisponibilite)
    VALUES (id_billet, NULL, prix_initial, 0, 0, TRUE);
END;
$$ LANGUAGE plpgsql;

-- Fonction pour créer plusieurs billets
CREATE OR REPLACE FUNCTION creer_billets(
    prix_initial DECIMAL(10, 2),
    nb_places INT
)
RETURNS VOID AS $$
DECLARE
    i INT;
BEGIN
    -- Vérification des contraintes
    IF prix_initial <= 0 THEN
        RAISE EXCEPTION 'Le prix final doit être supérieur à 0';
    END IF;
    
    -- Vérification du nombre de places
    IF nb_places <= 0 THEN
        RAISE EXCEPTION 'Le nombre de places doit être supérieur à 0';
    END IF;

    -- Insertion des billets
    FOR i IN 1..nb_places LOOP
        PERFORM creer_billet(prix_initial); -- Exemple de prix et promotion
    END LOOP;
END;
$$ LANGUAGE plpgsql;