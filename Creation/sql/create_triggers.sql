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

    INSERT INTO CreneauConnexion (CCjour_debut, CCheure_debut, CCetat, CCmax_connexions)
    VALUES (NEW.jour, NEW.heure, 'Ouvert', 100), 
           (NEW.jour, NEW.heure, 'En attente', 100),
            (NEW.jour, NEW.heure, 'Ferme', 0);


    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to control the insertion and update of the TEMPS table
CREATE TRIGGER controle_temps_trigger 
BEFORE UPDATE OR INSERT ON TEMPS
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


CREATE OR REPLACE FUNCTION verifier_etablissement_politique()
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
CREATE OR REPLACE FUNCTION generer_id_billet(
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
    billet_id TEXT;
BEGIN
    CATlist := ARRAY['Carre Or', 'Cat1', 'Cat2', 'Cat3', 'Cat4'];
    SELECT TEMPS.jour, TEMPS.heure INTO jour, heure FROM TEMPS LIMIT 1;

    IF NEW.Etype = 'Film' THEN
        SELECT c.CATnb_place, c.CATprix INTO CATnb_place, CATprix
        FROM Categorie c
        WHERE c.CATnom = 'Unique';
        FOR i IN 1..CATnb_place LOOP
            billet_id := generer_id_billet(NEW.Enom_complet, NEW.Enom_film, NEW.Ejour, NEW.Eheure, NEW.Enum_salle, i, 'Unique');
            INSERT INTO Billet (Bid, Bjour_achat, Bheure_achat, Bprix_initial, Bprix_achat, Bpromotion, Bdisponibilite, Bnum_place)
            VALUES (billet_id, jour, heure, CATprix, CATprix, 0, TRUE, i);

            INSERT INTO BilletEvenement (Bid, Enom_complet, Ejour, Eheure, Enum_salle)
            VALUES (billet_id, NEW.Enom_complet, NEW.Ejour, NEW.Eheure, NEW.Enum_salle);
        END LOOP;
    ELSIF NEW.Etype = 'SousEvenement' THEN
        SELECT c.CATnb_place, c.CATprix INTO CATnb_place, CATprix
        FROM Categorie c
        WHERE c.CATnom = 'UniqueVIP';        
        FOR i IN 1..CATnb_place LOOP
            billet_id := generer_id_billet(NEW.Enom_complet, NEW.Enom_film, NEW.Ejour, NEW.Eheure, NEW.Enum_salle, i, 'UniqueVIP');
            INSERT INTO Billet (Bid, Bjour_achat, Bheure_achat, Bprix_initial, Bprix_achat, Bpromotion, Bdisponibilite, Bnum_place)
            VALUES (billet_id, jour, heure, CATprix, CATprix, 0, TRUE, i);

            INSERT INTO BilletEvenement (Bid, Enom_complet, Ejour, Eheure, Enum_salle)
            VALUES (billet_id, NEW.Enom_complet, NEW.Ejour, NEW.Eheure, NEW.Enum_salle);
        END LOOP;
    ELSE 
        FOR i IN 1..array_length(CATlist, 1) LOOP
            SELECT c.CATnb_place, c.CATprix INTO CATnb_place, CATprix
            FROM Categorie c
            WHERE c.CATnom = CATlist[i];            
            FOR j IN 1..CATnb_place LOOP
                billet_id := generer_id_billet(NEW.Enom_complet, NEW.Enom_film, NEW.Ejour, NEW.Eheure, NEW.Enum_salle, j, CATlist[i]);
                INSERT INTO Billet (Bid, Bjour_achat, Bheure_achat, Bprix_initial, Bprix_achat, Bpromotion, Bdisponibilite, Bnum_place)
                VALUES (billet_id, jour, heure, CATprix, CATprix, 0, TRUE, j);

                INSERT INTO BilletEvenement (Bid, Enom_complet, Ejour, Eheure, Enum_salle)
                VALUES (billet_id, NEW.Enom_complet, NEW.Ejour, NEW.Eheure, NEW.Enum_salle);
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


CREATE OR REPLACE FUNCTION verifier_categorie_evenement()
RETURNS TRIGGER AS $$
DECLARE
    CATlist TEXT[];
BEGIN
    CATlist := ARRAY['Carre Or', 'Cat1', 'Cat2', 'Cat3', 'Cat4'];
    IF NEW.Etype = 'Film' THEN
        INSERT INTO CategorieEvenement (CATnom, Enom_complet, Ejour, Eheure, Enum_salle)
        VALUES ('Unique', NEW.Enom_complet, NEW.Ejour, NEW.Eheure, NEW.Enum_salle);
    ELSIF NEW.Etype = 'SousEvenement' THEN
        INSERT INTO CategorieEvenement (CATnom, Enom_complet, Ejour, Eheure, Enum_salle)
        VALUES ('UniqueVIP', NEW.Enom_complet, NEW.Ejour, NEW.Eheure, NEW.Enum_salle);
    ELSE 
        FOR i IN 1..array_length(CATlist, 1) LOOP
            INSERT INTO CategorieEvenement (CATnom, Enom_complet, Ejour, Eheure, Enum_salle)
            VALUES (CATlist[i], NEW.Enom_complet, NEW.Ejour, NEW.Eheure, NEW.Enum_salle);
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lien_categorie_evenement
AFTER INSERT ON Evenement
FOR EACH ROW
EXECUTE PROCEDURE verifier_categorie_evenement();

CREATE OR REPLACE FUNCTION verifier_sous_evenement()
RETURNS TRIGGER AS $$
DECLARE
    parent_id TEXT;
BEGIN
    IF NEW.Etype != 'SousEvenement' THEN
        RETURN NEW;
    END IF;

    -- Vérification de l'existence de l'événement parent
    SELECT Enom_complet INTO parent_id FROM Evenement 
    WHERE Enom_film = NEW.Enom_film 
    AND Ejour = NEW.Ejour 
    AND Eheure = NEW.Eheure 
    AND Enum_salle = NEW.Enum_salle 
    AND Enom_complet != NEW.Enom_complet
    AND (Etype = 'Film' OR Etype = 'Concert');

    IF parent_id IS NULL THEN
        RAISE EXCEPTION 'L événement parent % n existe pas', NEW.Eid_parent;
    END IF;

    NEW.Eid_parent := parent_id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER verifier_sous_evenement_trigger
BEFORE INSERT ON Evenement
FOR EACH ROW
EXECUTE PROCEDURE verifier_sous_evenement();

-- Trigger pour gérer la suppression des événements et billets
CREATE OR REPLACE FUNCTION check_after_timer_update()
RETURNS TRIGGER AS $$
DECLARE
    evenement_rec RECORD;
    billet_rec RECORD;
BEGIN

    UPDATE Utilisateur SET Uconnecte = FALSE WHERE Uconnecte = TRUE;

    -- DELETE FROM CreneauConnexion
    -- WHERE (jour < NEW.jour)
    --     OR (jour = NEW.jour AND heure < NEW.heure);

    FOR evenement_rec IN
        SELECT * FROM Evenement
        WHERE 
            (Ejour < NEW.jour)
            OR (
                (Ejour = NEW.jour)
                AND (Eheure < NEW.heure)
            )
    LOOP
        DELETE FROM BilletEvenement WHERE Enom_complet = evenement_rec.Enom_complet
            AND Ejour = evenement_rec.Ejour
            AND Eheure = evenement_rec.Eheure
            AND Enum_salle = evenement_rec.Enum_salle;
        DELETE FROM CreneauConnexionEvenement WHERE Enom_complet = evenement_rec.Enom_complet
            AND Ejour = evenement_rec.Ejour
            AND Eheure = evenement_rec.Eheure
            AND Enum_salle = evenement_rec.Enum_salle;
        DELETE FROM CategorieEvenement WHERE Enom_complet = evenement_rec.Enom_complet
            AND Ejour = evenement_rec.Ejour
            AND Eheure = evenement_rec.Eheure
            AND Enum_salle = evenement_rec.Enum_salle;
        DELETE FROM EvenementEtablissement WHERE Enom_complet = evenement_rec.Enom_complet
            AND Ejour = evenement_rec.Ejour
            AND Eheure = evenement_rec.Eheure
            AND Enum_salle = evenement_rec.Enum_salle;
        DELETE FROM Evenement WHERE Enom_complet = evenement_rec.Enom_complet
            AND Ejour = evenement_rec.Ejour
            AND Eheure = evenement_rec.Eheure
            AND Enum_salle = evenement_rec.Enum_salle;
    END LOOP;

    -- DELETE FROM Reservation
    -- WHERE (Rjour < NEW.jour)
    --     OR (Rjour = NEW.jour AND Rheure < NEW.heure);

    -- DELETE FROM CreneauConnexionUtilisateur
    -- WHERE (CCjour_debut < NEW.jour)
    --     OR (CCjour_debut = NEW.jour AND CCheure_debut < NEW.heure);
    
    -- DELETE FROM CreneauConnexionBillet
    -- WHERE (CCjour_debut < NEW.jour)
    --     OR (CCjour_debut = NEW.jour AND CCheure_debut < NEW.heure);

    FOR billet_rec IN
        SELECT Bid FROM Billet
        WHERE 
            (split_part(Bid, '-', 3)::int) < NEW.jour
            OR (
                (split_part(Bid, '-', 3)::int) = NEW.jour
                AND (split_part(Bid, '-', 4)::int) < NEW.heure
            )
    LOOP
        DELETE FROM Achat WHERE Bid = billet_rec.Bid;
        DELETE FROM Echange WHERE Bid = billet_rec.Bid;
        DELETE FROM CategorieBillet WHERE Bid = billet_rec.Bid;
        DELETE FROM Billet WHERE Bid = billet_rec.Bid;
        UPDATE Reservation
        SET Rstatut = 'Termine'
        WHERE Bid = billet_rec.Bid;
    END LOOP;

    INSERT INTO CreneauConnexion (CCjour_debut, CCheure_debut, CCetat, CCmax_connexions)
    VALUES (NEW.jour, NEW.heure, 'Ouvert', 100), 
           (NEW.jour, NEW.heure, 'En attente', 100),
              (NEW.jour, NEW.heure, 'Ferme', 0);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_after_timer
AFTER UPDATE ON TEMPS
FOR EACH ROW
EXECUTE PROCEDURE check_after_timer_update();


CREATE OR REPLACE FUNCTION check_user()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE Utilisateur
    SET Ususpect = TRUE
    WHERE Uemail IN (
        SELECT U.Uemail
        FROM Utilisateur U
        JOIN Reservation R ON U.Uemail = R.Uemail
        WHERE U.Uemail = NEW.Uemail
        GROUP BY U.Uemail
        HAVING 
            COUNT(CASE WHEN R.Rstatut = 'Annule' THEN 1 END) > 10 -- Plus de 10 annulations
            OR COUNT(R.Bid) > 50 -- Plus de 50 réservations
            -- C Cette partie à revoir
            -- OR (MAX(R.Rjour_debut) - MIN(R.Rjour_debut)) * 24 + (MAX(R.Rheure_debut) - MIN(R.Rheure_debut)) < 1 -- Durée moyenne < 1 heure
            -- OR (MAX(R.Rjour_debut * 24 + R.Rheure_debut) - MIN(R.Rjour_debut * 24 + R.Rheure_debut)) < 24 -- Réservations concentrées sur une journée
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_user
AFTER UPDATE ON TEMPS
FOR EACH ROW
EXECUTE FUNCTION check_user();

CREATE OR REPLACE FUNCTION nettoyage_creneaux_connexion()
RETURNS TRIGGER AS $$
DECLARE
    cce_rec RECORD;
BEGIN
    FOR cce_rec IN
        SELECT CCjour_debut, CCheure_debut, CCetat
        FROM CreneauConnexionEvenement
        WHERE 
            (CCjour_debut < NEW.jour)
            OR (CCjour_debut = NEW.jour AND CCheure_debut < NEW.heure)
    LOOP
        -- Suppression dans CreneauConnexionUtilisateur pour ce créneau et état
        DELETE FROM CreneauConnexionUtilisateur
        WHERE CCjour_debut = cce_rec.CCjour_debut
          AND CCheure_debut = cce_rec.CCheure_debut
          AND CCetat = cce_rec.CCetat;

        -- Suppression dans CreneauConnexionEvenement
        DELETE FROM CreneauConnexionEvenement
        WHERE CCjour_debut = cce_rec.CCjour_debut
          AND CCheure_debut = cce_rec.CCheure_debut
          AND CCetat = cce_rec.CCetat;

        -- Suppression dans CreneauConnexion
        DELETE FROM CreneauConnexion
        WHERE CCjour_debut = cce_rec.CCjour_debut
          AND CCheure_debut = cce_rec.CCheure_debut
          AND CCetat = cce_rec.CCetat;
    END LOOP;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER nettoyage_creneaux_connexion_trigger
AFTER UPDATE ON TEMPS
FOR EACH ROW
EXECUTE PROCEDURE nettoyage_creneaux_connexion();

-- Trigger pour vérifier l'existence de l'utilisateur destinataire lors d'un échange
CREATE OR REPLACE FUNCTION verif_utilisateur_destinataire()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM Utilisateur WHERE Uemail = NEW.Uemail_destinataire
    ) THEN
        RAISE EXCEPTION 'Utilisateur destinataire % inexistant', NEW.Uemail_destinataire;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_verif_utilisateur_destinataire
BEFORE INSERT ON Echange
FOR EACH ROW
EXECUTE FUNCTION verif_utilisateur_destinataire();