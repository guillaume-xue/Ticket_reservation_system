CREATE OR REPLACE FUNCTION check_is_evenement_prive(
    billet_id TEXT,
    email_utilisateur VARCHAR(255)
)
RETURNS BOOLEAN AS $$
DECLARE
    v_enom_complet TEXT;
    v_ejour INT;
    v_eheure INT;
    v_enum_salle INT;
    v_ccetat TEXT;
    is_autorise BOOLEAN := FALSE;
    jour_courant INT;
    heure_courant INT;
BEGIN
    -- Récupérer les infos de l'événement associé au billet
    SELECT Enom_complet, Ejour, Eheure, Enum_salle
    INTO v_enom_complet, v_ejour, v_eheure, v_enum_salle
    FROM BilletEvenement
    WHERE Bid = billet_id;

    -- Récupérer le temps courant
    SELECT jour, heure INTO jour_courant, heure_courant FROM TEMPS LIMIT 1;

    

    -- Vérifier si cet événement existe dans CreneauConnexionEvenement et récupérer le CCetat
    SELECT CCetat, CCjour_debut, CCheure_debut INTO v_ccetat, v_ejour, v_eheure
    FROM CreneauConnexionEvenement
    WHERE Enom_complet = v_enom_complet
      AND Ejour = v_ejour
      AND Eheure = v_eheure
      AND Enum_salle = v_enum_salle
    LIMIT 1;

    
    IF FOUND THEN
        -- Vérifier que le billet correspond au créneau temporel actuel
        IF v_ejour IS NULL OR v_eheure IS NULL OR v_ejour <> jour_courant OR v_eheure <> heure_courant THEN
            RETURN FALSE;
        END IF;
        -- Vérifier si l'utilisateur est autorisé pour ce créneau
        SELECT TRUE INTO is_autorise
        FROM CreneauConnexionUtilisateur
        WHERE CCetat = v_ccetat
          AND Uemail = email_utilisateur
        LIMIT 1;
        RETURN is_autorise;
    ELSE
        -- Ce n'est pas un événement privé, donc l'utilisateur est autorisé
        RETURN TRUE;
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Fonction pour pré-réserver un billet
-- Cette fonction vérifie la disponibilité du billet et l'associe à l'utilisateur
-- en mettant à jour la table Billet et en insérant une nouvelle réservation
-- dans la table Reservation.
CREATE OR REPLACE FUNCTION pre_reserver_billet(
    user_email VARCHAR(255),
    billet_id TEXT
)
RETURNS VOID AS $$
DECLARE
    nb_max_billets INT;
    billet_disponible BOOLEAN;
    jour_courant INT;
    heure_courant INT;
BEGIN
    IF NOT (SELECT check_is_evenement_prive(billet_id, user_email)) THEN
        RAISE EXCEPTION 'Le billet % est associé à un événement privé', billet_id;
    END IF;

    -- Vérification de la disponibilité du billet
    SELECT B.Bdisponibilite INTO billet_disponible
    FROM Billet B
    WHERE B.Bid = billet_id
      AND B.Bdisponibilite = TRUE
    FOR UPDATE;

    IF NOT billet_disponible THEN
        RAISE EXCEPTION 'Le billet % n''est pas disponible', billet_id;
    END IF;

    -- Avoir le nombre maximum de billets autorisés pour l'utilisateur
    SELECT U.Unb_max_billets INTO nb_max_billets
    FROM Utilisateur U
    WHERE U.Uemail = user_email;

    -- Vérifier si l'utilisateur existe
    IF nb_max_billets IS NULL THEN
        RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
    END IF;

    -- Vérifier le nombre de pré-réservations
    IF (SELECT COUNT(*)
        FROM Reservation R
        WHERE R.Uemail = user_email
          AND R.Rstatut = 'Pre-reserve') >= nb_max_billets THEN
        RAISE EXCEPTION 'Limite de pré-réservations atteinte pour l''utilisateur %', user_email;
    END IF;

    -- Récupérer le jour et l'heure actuels
    SELECT T.jour, T.heure INTO jour_courant, heure_courant
    FROM TEMPS T LIMIT 1;

    -- Insertion de la pré-réservation
    INSERT INTO Reservation (Uemail, Bid, Rjour_debut, Rheure_debut, Rstatut)
    VALUES (user_email, billet_id, jour_courant, heure_courant, 'Pre-reserve');

    -- Mettre à jour la disponibilité du billet
    UPDATE Billet
    SET Bdisponibilite = FALSE
    WHERE Bid = billet_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour confirmer une réservation
-- Cette fonction met à jour le statut de la réservation et le prix d'achat
-- dans la table Billet.
CREATE OR REPLACE FUNCTION confirmer_reservation(
    user_email VARCHAR(255),
    billet_id TEXT,
    promotion INT DEFAULT 0
)
RETURNS VOID AS $$
DECLARE
    prix_achat DECIMAL(10, 2);
    billet_disponible BOOLEAN;
BEGIN

    -- Vérifier si l'utilisateur a une réservation en attente
    PERFORM 1
    FROM Reservation
    WHERE Uemail = user_email
      AND Bid = billet_id
      AND (Rstatut = 'Pre-reserve' OR Rstatut = 'Reserve')
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aucune réservation trouvée pour le billet %', billet_id;
    END IF;

    -- Vérification de la disponibilité du billet
    SELECT Bdisponibilite INTO billet_disponible
    FROM Billet
    WHERE Bid = billet_id
      AND Bdisponibilite = TRUE
    FOR UPDATE;

    -- Mettre à jour le statut de la réservation et le prix d'achat
    UPDATE Reservation
    SET Rstatut = 'Confirme'
    WHERE Uemail = user_email
      AND Bid = billet_id;

    -- Récupérer le prix d'achat du billet
    SELECT C.CATprix INTO prix_achat
    FROM CategorieBillet CB
    JOIN Categorie C ON CB.CATnom = C.CATnom
    WHERE CB.Bid = billet_id;

    -- Appliquer la promotion si elle est fournie
    IF promotion IS NOT NULL THEN
        prix_achat := prix_achat * ((100 - promotion) / 100);
    END IF;

    -- Mettre à jour le prix d'achat du billet
    UPDATE Billet
    SET Bprix_achat = prix_achat,
        Bdisponibilite = FALSE,
        Bpromotion = promotion
    WHERE Bid = billet_id;
END;
$$ LANGUAGE plpgsql;


-- Fonction pour réserver un billet
-- Cette fonction vérifie la disponibilité du billet et l'associe à l'utilisateur
-- en mettant à jour la table Billet et en insérant une nouvelle réservation
-- dans la table Reservation.
CREATE OR REPLACE FUNCTION reserver_billet(
    user_email VARCHAR(255),
    billet_id TEXT,
    jour INT,
    heure INT
)
RETURNS VOID AS $$
DECLARE
    nb_max_billets INT;
    billet_disponible BOOLEAN;
BEGIN
    -- Vérification de la disponibilité du billet
    SELECT Bdisponibilite INTO billet_disponible
    FROM Billet
    WHERE Bid = billet_id
      AND Bdisponibilite = TRUE
    FOR UPDATE;

    IF NOT billet_disponible THEN
        RAISE EXCEPTION 'Le billet % n''est pas disponible', billet_id;
    END IF;

    -- Avoir le nombre maximum de billets autorisés pour l'utilisateur
    SELECT Unb_max_billets INTO nb_max_billets
    FROM Utilisateur
    WHERE Uemail = user_email;

    -- Vérifier si l'utilisateur existe
    IF nb_max_billets IS NULL THEN
        RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
    END IF;

    -- Mettre à jour la disponibilité du billet
    UPDATE Billet
    SET Bdisponibilite = FALSE
    WHERE Bid = billet_id;

    -- Insertion de la réservation
    INSERT INTO Reservation (Uemail, Bid, Rjour_debut, Rheure_debut, Rstatut)
    VALUES (user_email, billet_id, jour, heure, 'Reserve');
    -- Mettre à jour le prix d'achat du billet
    UPDATE Billet
    SET Bprix_achat = Bprix_initial,
        Bdisponibilite = FALSE
    WHERE Bid = billet_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour annuler une réservation
-- Cette fonction met à jour le statut de la réservation et remet le billet
-- à la disponibilité.
CREATE OR REPLACE FUNCTION annuler_reservation(
    user_email VARCHAR(255),
    billet_id TEXT
)
RETURNS VOID AS $$
DECLARE
    billet_disponible BOOLEAN;
BEGIN

    -- Vérifier si l'utilisateur a une réservation en attente
    PERFORM 1
    FROM Reservation
    WHERE Uemail = user_email
      AND Bid = billet_id
      AND (Rstatut = 'Reserve' OR Rstatut = 'Pre-reserve')
    FOR UPDATE;

    -- Vérifier si la réservation existe
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aucune réservation trouvée pour le billet %', billet_id;
    END IF;

    SELECT Bdisponibilite INTO billet_disponible
    FROM Billet
    WHERE Bid = billet_id
    FOR UPDATE;

    -- Mettre à jour le statut de la réservation et remettre le billet à la disponibilité
    UPDATE Reservation
    SET Rstatut = 'Annule'
    WHERE Uemail = user_email
      AND Bid = billet_id;

    -- Remettre le billet à la disponibilité
    UPDATE Billet
    SET Bdisponibilite = TRUE
    WHERE Bid = billet_id;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour récupérer les utilisateurs suspects
-- Cette fonction retourne les utilisateurs qui ont un nombre de réservations
-- supérieur ou égal à un seuil donné.
CREATE OR REPLACE FUNCTION utilisateurs_suspects_reservations(
    seuil_reservations INT DEFAULT 3
)
RETURNS TABLE (
    Uemail VARCHAR,
    nb_reservations INT,
    Rjour_debut INT,
    Rheure_debut INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        Reservation.Uemail,
        COUNT(*)::INT AS nb_reservations,
        Reservation.Rjour_debut,
        Reservation.Rheure_debut
    FROM Reservation
    GROUP BY Reservation.Uemail, Reservation.Rjour_debut, Reservation.Rheure_debut
    HAVING COUNT(*) >= seuil_reservations;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour gérer les créneaux de connexion
CREATE OR REPLACE FUNCTION gerer_creneau_connexion(
    user_email VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    statut_utilisateur VARCHAR(255);
    connexions_actuelles INT;
    max_connexions_actif INT;
    max_server_connexions INT;  
    jour INT;
    heure INT;
BEGIN
    SELECT T.jour, T.heure INTO jour, heure
    FROM TEMPS T LIMIT 1;

    -- Récupérer le nombre de connexions actives
    SELECT COUNT(*) INTO connexions_actuelles
    FROM CreneauConnexionUtilisateur CCU
    WHERE CCU.CCjour_debut = jour
      AND CCU.CCheure_debut = heure;

    SELECT COALESCE(SUM(C.CCmax_connexions), 0) INTO max_server_connexions
    FROM CreneauConnexion C
    WHERE C.CCjour_debut = jour
      AND C.CCheure_debut = heure
      AND (C.CCetat = 'Ouvert' OR C.CCetat = 'En attente');

    SELECT C.CCmax_connexions INTO max_connexions_actif
    FROM CreneauConnexion C
    WHERE C.CCjour_debut = jour
      AND C.CCheure_debut = heure
      AND C.CCetat = 'Ouvert';

    IF connexions_actuelles >= max_server_connexions THEN
        INSERT INTO CreneauConnexionUtilisateur (CCjour_debut, CCheure_debut, Uemail, CCetat)
        VALUES (jour, heure, user_email, 'Ferme');
        RAISE EXCEPTION 'Charge système maximale atteinte. Veuillez réessayer plus tard.'; 
    ELSIF connexions_actuelles >= max_connexions_actif THEN
        INSERT INTO CreneauConnexionUtilisateur (CCjour_debut, CCheure_debut, Uemail, CCetat)
        VALUES (jour, heure, user_email, 'En attente');
    ELSE
        INSERT INTO CreneauConnexionUtilisateur (CCjour_debut, CCheure_debut, Uemail, CCetat)
        VALUES (jour, heure, user_email, 'Ouvert');
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION gerer_reservation_automatique(
    user_email VARCHAR(255),
    billet_id TEXT,
    jour_dernier_reservation INT,
    heure_dernier_reservation INT,
    jour_premiere_reservation INT,
    heure_premiere_reservation INT
)
RETURNS BOOLEAN AS $$
DECLARE
    statut_utilisateur VARCHAR(255);
    connexions_actuelles INT;
    max_connexions INT;
    connexions_utilisateur INT;
    nb_max_billets INT;
    billet_disponible BOOLEAN;
BEGIN
    -- Démarrer une transaction
    BEGIN
        -- Vérifier si l'utilisateur existe et récupérer son statut
        SELECT Ustatut, Unb_max_billets INTO statut_utilisateur, nb_max_billets
        FROM Utilisateur
        WHERE Uemail = user_email;

        IF statut_utilisateur IS NULL THEN
            RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
        END IF;

        -- Vérifier la disponibilité du billet
        SELECT Bdisponibilite INTO billet_disponible
        FROM Billet
        WHERE Bid = billet_id;

        IF NOT billet_disponible THEN
            RAISE EXCEPTION 'Le billet % n''est pas disponible', billet_id;
        END IF;

        -- Vérifier le nombre de connexions actives
        SELECT COUNT(*) INTO connexions_actuelles
        FROM Utilisateur
        WHERE Uconnecte = TRUE;

        -- Vérifier la charge système (limiter à 100 connexions simultanées)
        SELECT max_connexions INTO max_connexions
        FROM CreneauConnexion
        WHERE jour_debut * 24 + heure_debut <= (SELECT jour * 24 + heure FROM TEMPS LIMIT 1)
            AND jour_fin * 24 + heure_fin >= (SELECT jour * 24 + heure FROM TEMPS LIMIT 1);

        IF max_connexions IS NULL THEN
            max_connexions := 100; -- Valeur par défaut si aucune connexion active
        END IF;

        IF connexions_actuelles >= max_connexions THEN
            RAISE EXCEPTION 'Charge système maximale atteinte. Veuillez réessayer plus tard.';
        END IF;

        -- Vérifier l'historique de l'utilisateur (limiter à 3 connexions actives)
        SELECT COUNT(*) INTO connexions_utilisateur
        FROM CreneauConnexion
        WHERE Uemail = user_email
            AND jour_fin * 24 + heure_fin > (SELECT jour * 24 + heure FROM TEMPS LIMIT 1);

        IF connexions_utilisateur >= 3 THEN
            RAISE EXCEPTION 'Utilisateur % a atteint la limite de connexions actives.', user_email;
        END IF;

        -- Vérifier le nombre de pré-réservations
        IF (SELECT COUNT(*)
            FROM Reservation
            WHERE Uemail = user_email
              AND Rstatut = 'Pre-reserve') >= nb_max_billets THEN
            RAISE EXCEPTION 'Limite de pré-réservations atteinte pour l''utilisateur %', user_email;
        END IF;

        -- Insérer le créneau de connexion
        INSERT INTO CreneauConnexion (CCjour_debut, CCheure_debut, CCetat)
        VALUES (jour_debut, heure_debut, 'Ouvert');

        -- Mettre à jour la disponibilité du billet
        UPDATE Billet
        SET Bdisponibilite = FALSE
        WHERE Bid = billet_id;

        -- Insertion de la pré-réservation
        INSERT INTO Reservation (Uemail, Bid, Rjour_debut, Rheure_debut, Rstatut)
        VALUES (user_email, billet_id, jour_premiere_reservation, heure_premiere_reservation, 'Pre-reserve');

        -- Vérifier les comportements suspects et mettre à jour Ususpect
        UPDATE Utilisateur
        SET Ususpect = TRUE
        WHERE Uemail IN (
            SELECT U.Uemail
            FROM Utilisateur U
            JOIN Reservation R ON U.Uemail = R.Uemail
            GROUP BY U.Uemail
            HAVING 
                COUNT(CASE WHEN R.Rstatut = 'Annule' THEN 1 END) > 10 -- Plus de 10 annulations
                OR COUNT(R.Bid) > 50 -- Plus de 50 réservations
                OR (jour_dernier_reservation - jour_premiere_reservation) * 24 + (heure_dernier_reservation - heure_premiere_reservation) < 1 -- Durée moyenne < 1 heure
                OR MAX(R.Rjour_fin * 24 + R.Rheure_fin) - MIN(R.Rjour_debut * 24 + R.Rdate_heure_debut) < INTERVAL '1 day' -- Réservations concentrées sur une journée
        );

        -- Si tout se passe bien, valider la transaction
        COMMIT;
        RETURN TRUE;

    EXCEPTION
        WHEN OTHERS THEN
            -- En cas d'erreur, annuler la transaction
            ROLLBACK;
            RAISE;
    END;
END;
$$ LANGUAGE plpgsql;

-- Ajouter un evenement à un établissement
-- Cette fonction insère un événement dans la table Evenement et
-- crée une relation entre l'événement et l'établissement dans la table EvenementEtablissement.
CREATE OR REPLACE FUNCTION inserer_evenement(
    nom_complet TEXT,
    nom_film VARCHAR,
    jour_debut INT,
    heure_debut INT,
    num_salle INT,
    Edescription TEXT,
    type_evenement VARCHAR,
    ETAadresse VARCHAR,
    ETAnom VARCHAR
)
RETURNS VOID AS $$
BEGIN
    -- Insertion de l'événement dans la table Evenement
    INSERT INTO Evenement (Enom_complet, Enom_film, Ejour, Eheure, Enum_salle, Edescription, Etype)
    VALUES (nom_complet, nom_film, jour_debut, heure_debut, num_salle, Edescription, type_evenement);

    -- Insertion de la relation entre l'événement et l'établissement
    INSERT INTO EvenementEtablissement (Enom_complet, Ejour, Eheure, Enum_salle, ETAadresse, ETAnom)
    VALUES (nom_complet, jour_debut, heure_debut, num_salle, ETAadresse, ETAnom);
END;
$$ LANGUAGE plpgsql;

-- Ajouter un utilisateur
-- Cette fonction insère un nouvel utilisateur dans la table Utilisateur.
CREATE OR REPLACE FUNCTION inserer_utilisateur(
    email VARCHAR(255),
    nom VARCHAR(255),
    prenom VARCHAR(255),
    statut VARCHAR(32)
)
RETURNS VOID AS $$
BEGIN
    -- Insertion de l'utilisateur dans la table Utilisateur
    INSERT INTO Utilisateur (Uemail, Unom, Uprenom, Ustatut, Uconnecte, Ususpect)
    VALUES (email, nom, prenom, statut, FALSE, FALSE);
END;
$$ LANGUAGE plpgsql;

-- Fonction pour gérer la connexion d'un utilisateur
-- Cette fonction met à jour le statut de l'utilisateur à connecté
-- et gère les créneaux de connexion.
CREATE OR REPLACE FUNCTION connexion_utilisateur(
    user_email VARCHAR(255)
)
RETURNS VOID AS $$
BEGIN
    -- Vérifier si l'utilisateur existe
    IF NOT EXISTS (
        SELECT 1
        FROM Utilisateur U
        WHERE U.Uemail = user_email
    ) THEN
        RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
    END IF;

    PERFORM gerer_creneau_connexion(user_email);

    -- Mettre à jour le statut de l'utilisateur à connecté
    UPDATE Utilisateur
    SET Uconnecte = TRUE
    WHERE Uemail = user_email;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour gérer la déconnexion d'un utilisateur
-- Cette fonction met à jour le statut de l'utilisateur à déconnecté
-- et gère les créneaux de connexion.
CREATE OR REPLACE FUNCTION deconnexion_utilisateur(
    user_email VARCHAR(255)
)
RETURNS VOID AS $$
BEGIN
    -- Vérifier si l'utilisateur existe
    IF NOT EXISTS (
        SELECT 1
        FROM Utilisateur U
        WHERE U.Uemail = user_email
    ) THEN
        RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
    END IF;

    DELETE FROM CreneauConnexionUtilisateur
    WHERE Uemail = user_email;

    -- Mettre à jour le statut de l'utilisateur à déconnecté
    UPDATE Utilisateur
    SET Uconnecte = FALSE
    WHERE Uemail = user_email;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour incrémenter le jour dans la table TEMPS
CREATE OR REPLACE FUNCTION increment_temps_jour()
RETURNS VOID AS $$
BEGIN
    -- Incrémenter le jour de 1 
    UPDATE TEMPS
    SET jour = jour + 1, 
        heure = 0;

END;
$$ LANGUAGE plpgsql;

-- Fonction pour incrémenter l'heure dans la table TEMPS
CREATE OR REPLACE FUNCTION increment_temps_heure()
RETURNS VOID AS $$
BEGIN
    -- Incrémenter l'heure de 1
    UPDATE TEMPS
    SET heure = heure + 1;

    -- Si l'heure atteint 24, incrémenter le jour de 1 et réinitialiser l'heure à 0
    IF (SELECT heure FROM TEMPS) >= 24 THEN
        PERFORM increment_temps_jour();
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour générer un ID de billet unique
CREATE OR REPLACE FUNCTION generer_id_evenement(
    nom_complet TEXT,
    jour INT,
    heure INT,
    num_salle INT
) 
RETURNS TEXT AS $$
BEGIN
    RETURN nom_complet || '-' || jour || '-' || heure || '-' || num_salle;
END;
$$ LANGUAGE plpgsql;

-- Fonction pour gérer les événements privés
-- Cette fonction insère un événement privé dans la table Evenement
-- et crée une relation entre l'événement privé et le créneau de connexion
-- dans la table CreneauConnexion.
CREATE OR REPLACE FUNCTION evenement_sur_reservation(
    nom_complet TEXT,
    jour_param INT,
    heure_param INT,
    num_salle INT,
    jour_reservation INT,
    heure_reservation INT   
)
RETURNS VOID AS $$
DECLARE
    evenement_id TEXT;
    nb_places INT;
    type_evenement VARCHAR;
BEGIN
    SELECT e.Enom_complet, e.Etype INTO evenement_id, type_evenement
    FROM Evenement e
    WHERE e.Enom_complet = nom_complet
      AND e.Ejour = jour_param
      AND e.Eheure = heure_param
      AND e.Enum_salle = num_salle;

    IF evenement_id IS NULL THEN
        RAISE EXCEPTION 'Événement % non trouvé', evenement_id;
    END IF;

    evenement_id := generer_id_evenement(nom_complet, jour_param, heure_param, num_salle);

    IF type_evenement IS NULL THEN
        RAISE EXCEPTION 'Type d''événement non trouvé pour %', nom_complet;
    ELSIF type_evenement = 'Film' THEN
        SELECT c.CATnb_place INTO nb_places
        FROM Categorie c
        WHERE c.CATnom = 'Unique';
    ELSIF type_evenement = 'Concert' THEN
        SELECT SUM(c.CATnb_place) INTO nb_places
        FROM Categorie c
        WHERE c.CATnom IN ('Carre Or', 'Cat1', 'Cat2', 'Cat3', 'Cat4');
    ELSIF type_evenement = 'SousEvenement' THEN
        SELECT c.CATnb_place INTO nb_places
        FROM Categorie c
        WHERE c.CATnom = 'UniqueVIP';
    ELSE
        RAISE EXCEPTION 'Type événement non pris en charge pour %', nom_complet;
    END IF;

    INSERT INTO CreneauConnexion (CCjour_debut, CCheure_debut, CCetat, CCmax_connexions)
    VALUES (jour_reservation, heure_reservation, evenement_id, nb_places);

    INSERT INTO CreneauConnexionEvenement (CCjour_debut, CCheure_debut, CCetat, Enom_complet, Ejour, Eheure, Enum_salle)
    VALUES (jour_reservation, heure_reservation, evenement_id, nom_complet, jour_param, heure_param, num_salle);
END;
$$ LANGUAGE plpgsql;

-- Fonction pour inscrire un utilisateur à un événement privé
CREATE OR REPLACE FUNCTION inscription_evenement_prive(
    user_email VARCHAR(255),
    nom_complet TEXT
)
RETURNS VOID AS $$
DECLARE
    nb_connexions INT;
    max_connexions INT;
    jour_evt INT;
    heure_evt INT;
BEGIN
    -- Vérifier si l'utilisateur existe
    IF NOT EXISTS (
        SELECT 1
        FROM Utilisateur
        WHERE Uemail = user_email
    ) THEN
        RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
    END IF;

    -- Vérifier si l'événement existe
    IF NOT EXISTS (
        SELECT 1
        FROM CreneauConnexion
        WHERE CCetat = nom_complet
    ) THEN
        RAISE EXCEPTION 'Événement % non trouvé', nom_complet;
    END IF;

    SELECT COUNT(*) INTO nb_connexions
    FROM CreneauConnexionUtilisateur
    WHERE CCetat = nom_complet;

    SELECT CCmax_connexions, CCjour_debut, CCheure_debut INTO max_connexions, jour_evt, heure_evt
    FROM CreneauConnexion
    WHERE CCetat = nom_complet;

    IF nb_connexions >= max_connexions THEN
        RAISE EXCEPTION 'Le nombre maximum de pré inscription pour événement % a été atteint', nom_complet;
    END IF;

    INSERT INTO CreneauConnexionUtilisateur (CCjour_debut, CCheure_debut, CCetat, Uemail)
    VALUES (jour_evt, heure_evt, nom_complet, user_email);

END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION initier_echange(
    billet_id TEXT,
    user_email VARCHAR(255),
    prix DECIMAL(10, 2)
)
RETURNS VOID AS $$
DECLARE
    v_ejour INT;
    v_eheure INT;
BEGIN
    -- Vérifier que l'utilisateur possède bien le billet en statut 'Reserve' ou 'Confirme'
    IF NOT EXISTS (
        SELECT 1 FROM Reservation
        WHERE Uemail = user_email
          AND Bid = billet_id
          AND Rstatut = 'Confirme'
    ) THEN
        RAISE EXCEPTION 'L''utilisateur % ne possède pas le billet % ou le billet n''est pas échangeable', user_email, billet_id;
    END IF;

    -- Récupérer le jour et l'heure de l'achat'
    SELECT Rjour_debut, Rheure_debut INTO v_ejour, v_eheure
    FROM Reservation
    WHERE Uemail = user_email
      AND Bid = billet_id
    LIMIT 1;

    -- Insérer l'échange (destinataire NULL au départ)
    INSERT INTO Echange (Uemail_emetteur, Uemail_destinataire, Bid, ECjour, ECheure, ECprix)
    VALUES (user_email, NULL, billet_id, v_ejour, v_eheure, prix);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION effectuer_echange(
    billet_id TEXT,
    emetteur VARCHAR(255),
    destinataire VARCHAR(255)
)
RETURNS VOID AS $$
DECLARE
    v_ejour INT;
    v_eheure INT;
BEGIN
    -- Vérifier que l'échange existe et que le billet appartient bien à l'émetteur
    IF NOT EXISTS (
        SELECT 1 FROM Echange
        WHERE Bid = billet_id
          AND Uemail_emetteur = emetteur
          AND Uemail_destinataire IS NULL
    ) THEN
        RAISE EXCEPTION 'Aucun échange disponible pour ce billet ou déjà pris.';
    END IF;

    -- Vérifier que le destinataire n'a pas déjà ce billet
    IF EXISTS (
        SELECT 1 FROM Reservation
        WHERE Uemail = destinataire
          AND Bid = billet_id
    ) THEN
        RAISE EXCEPTION 'Le destinataire possède déjà ce billet.';
    END IF;

    -- Vérifier que le destinataire n'a pas atteint la limite de pré-réservations
    IF (SELECT COUNT(*)
        FROM Reservation
        WHERE Uemail = destinataire
          AND Rstatut = 'Pre-reserve') >= (SELECT Unb_max_billets FROM Utilisateur WHERE Uemail = destinataire) THEN
        RAISE EXCEPTION 'Limite de pré-réservations atteinte pour l''utilisateur %', destinataire;
    END IF;

    -- Récupérer le jour et l'heure de la réservation
    SELECT Rjour_debut, Rheure_debut INTO v_ejour, v_eheure
    FROM Reservation
    WHERE Uemail = emetteur
      AND Bid = billet_id
    LIMIT 1;

    -- Supprimer la réservation de l'émetteur
    DELETE FROM Reservation
    WHERE Uemail = emetteur
      AND Bid = billet_id;

    -- Créer la réservation pour le destinataire
    INSERT INTO Reservation (Uemail, Bid, Rjour_debut, Rheure_debut, Rstatut)
    VALUES (destinataire, billet_id, v_ejour, v_eheure, 'Confirme');

    -- Mettre à jour le prix d'achat du billet
    UPDATE Billet
    SET Bprix_achat = (SELECT ECprix FROM Echange WHERE Bid = billet_id AND Uemail_emetteur = emetteur)
    WHERE Bid = billet_id;

    -- Mettre à jour l'échange (ajouter le destinataire)
    UPDATE Echange
    SET Uemail_destinataire = destinataire
    WHERE Bid = billet_id
      AND Uemail_emetteur = emetteur
      AND Uemail_destinataire IS NULL;

    DELETE FROM Echange WHERE Bid = billet_id AND Uemail_emetteur = emetteur;

END;
$$ LANGUAGE plpgsql;
