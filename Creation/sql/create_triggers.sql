CREATE OR REPLACE FUNCTION controle_temps() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.jour < OLD.jour THEN 
            RAISE EXCEPTION 'Impossible';
        ELSIF NEW.jour = OLD.jour AND NEW.heure < OLD.heure THEN 
            RAISE EXCEPTION 'Impossible';
        END IF;
        ELSIF TG_OP = 'INSERT' THEN
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


CREATE FUNCTION verifier_etablissement_politique()
RETURNS TRIGGER AS $$
BEGIN
    -- Vérification de l'existence de la politique d'établissement
    IF NOT EXISTS (SELECT 1 FROM PolitiqueEtablissement WHERE PEtitre = NEW.ETAnom) THEN
        RAISE EXCEPTION 'La politique d établissement % n existe pas', NEW.ETAnom;
    END IF;

    INSERT INTO EtablissementPolitique (ETAadresse, ETAnom, PEtitre)
    VALUES (NEW.ETAadresse, NEW.ETAnom, NEW.ETAnom);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lien_etablissment_politique
AFTER INSERT ON Etablissement
FOR EACH ROW
EXECUTE PROCEDURE verifier_etablissement_politique();


-- Fonction pour générer un ID de billet unique
CREATE FUNCTION generer_id_billet(
    Eid TEXT,
    Enom VARCHAR(255),
    Ejour INT,
    Eheure INT,
    Enum_salle INT,
    Bnum_place INT,
    CATnom VARCHAR(255)
) 
RETURNS TEXT AS $$
BEGIN
    RETURN Eid || '-' || Enom || '-' || Ejour || '-' || Eheure || '-' || Enum_salle || '-' || Bnum_place || '-' || CATnom;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour créer plusieurs billets
CREATE OR REPLACE FUNCTION creer_billets()
RETURNS TRIGGER AS $$
DECLARE
    CATnb_place INT;
    CATprix DECIMAL(10, 2);
    jour INT;
    heure INT;
    CATlist TEXT[];
BEGIN
    CATlist := ARRAY['Carre Or', 'Cat1', 'Cat2', 'Cat3', 'Cat4'];
    SELECT TEMPS.jour, TEMPS.heure INTO jour, heure FROM TEMPS LIMIT 1;

    IF NEW.Etype = 'Film' THEN
        SELECT c.CATnb_place, c.CATprix INTO CATnb_place, CATprix
        FROM Categorie c
        WHERE c.CATnom = 'Unique';
        FOR i IN 1..CATnb_place LOOP
            INSERT INTO Billet (Bid, Bjour_achat, Bheure_achat, Bprix_initial, Bprix_achat, Bpromotion, Bdisponibilite, Bnum_place)
            VALUES (generer_id_billet(NEW.Eid, NEW.Enom, NEW.Ejour, NEW.Eheure, NEW.Enum_salle, i, 'Unique'), jour, heure, CATprix, CATprix, 0, TRUE, i);
        END LOOP;
    ELSIF NEW.Etype = 'SousEvenement' THEN
        SELECT c.CATnb_place, c.CATprix INTO CATnb_place, CATprix
        FROM Categorie c
        WHERE c.CATnom = 'UniqueVIP';        
        FOR i IN 1..CATnb_place LOOP
            INSERT INTO Billet (Bid, Bjour_achat, Bheure_achat, Bprix_initial, Bprix_achat, Bpromotion, Bdisponibilite, Bnum_place)
            VALUES (generer_id_billet(NEW.Eid, NEW.Enom, NEW.Ejour, NEW.Eheure, NEW.Enum_salle, i, 'UniqueVIP'), jour, heure, CATprix, CATprix, 0, TRUE, i);
        END LOOP;
    ELSE 
        FOR i IN 1..array_length(CATlist, 1) LOOP
            SELECT c.CATnb_place, c.CATprix INTO CATnb_place, CATprix
            FROM Categorie c
            WHERE c.CATnom = CATlist[i];            
            FOR j IN 1..CATnb_place LOOP
                INSERT INTO Billet (Bid, Bjour_achat, Bheure_achat, Bprix_initial, Bprix_achat, Bpromotion, Bdisponibilite, Bnum_place)
                VALUES (generer_id_billet(NEW.Eid, NEW.Enom, NEW.Ejour, NEW.Eheure, NEW.Enum_salle, j, CATlist[i]), jour, heure, CATprix, CATprix, 0, TRUE, j);
            END LOOP;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER creer_billets_trigger
AFTER INSERT ON Evenement
FOR EACH ROW
EXECUTE PROCEDURE creer_billets();


-- Fonction de trigger pour insérer dans CategorieBillet après ajout d'un billet
CREATE OR REPLACE FUNCTION inserer_categorie_billet()
RETURNS TRIGGER AS $$
DECLARE
    CATnom VARCHAR(255);
BEGIN
    CATnom := split_part(NEW.Bid, '-', 7);

    INSERT INTO CategorieBillet (CATnom, Bid)
    VALUES (CATnom, NEW.Bid);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger sur la table Billet
CREATE TRIGGER ajout_categorie_billet_trigger
AFTER INSERT ON Billet
FOR EACH ROW
EXECUTE PROCEDURE inserer_categorie_billet();


CREATE FUNCTION verifier_categorie_evenement()
RETURNS TRIGGER AS $$
DECLARE
    CATlist TEXT[];
BEGIN
    CATlist := ARRAY['Carre Or', 'Cat1', 'Cat2', 'Cat3', 'Cat4'];
    IF NEW.Etype = 'Film' THEN
        INSERT INTO CategorieEvenement (CATnom, Eid)
        VALUES ('Unique', NEW.Eid);
    ELSIF NEW.Etype = 'SousEvenement' THEN
        INSERT INTO CategorieEvenement (CATnom, Eid)
        VALUES ('UniqueVIP', NEW.Eid);
    ELSE 
        FOR i IN 1..array_length(CATlist, 1) LOOP
            INSERT INTO CategorieEvenement (CATnom, Eid)
            VALUES (CATlist[i], NEW.Eid);
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lien_categorie_evenement
AFTER INSERT ON Evenement
FOR EACH ROW
EXECUTE PROCEDURE verifier_categorie_evenement();