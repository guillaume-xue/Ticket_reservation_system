-- Fonction pour récupérer les événements disponibles pour un utilisateur
CREATE OR REPLACE FUNCTION recuperer_evenements_disponibles(
    user_email VARCHAR(255)
)
RETURNS TABLE (
    evenement_id TEXT,
    nom_evenement VARCHAR(255),
    jour_evenement INT,
    heure_evenement INT,
    description_evenement TEXT,
    type_evenement VARCHAR(32)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        E.nom_complet AS evenement_id,
        E.Enom AS nom_evenement,
        E.Ejour AS jour_evenement,
        E.Eheure AS heure_evenement,
        E.Edescription AS description_evenement,
        E.Etype AS type_evenement
    FROM Evenement E
    JOIN CategorieEvenement CE ON E.Enom_complet = CE.Enom_complet 
        AND E.Ejour = CE.Ejour
        AND E.Eheure = CE.Eheure
        AND E.Enum_salle = CE.Enum_salle
    JOIN Categorie C ON CE.CATnom = C.CATnom
    JOIN Utilisateur U ON U.Uemail = user_email
    WHERE U.Ustatut IN ('Normal', 'VIP', 'VVIP') -- Filtrage par statut
      AND C.CATprix <= (
          CASE 
              WHEN U.Ustatut = 'Normal' THEN 50
              WHEN U.Ustatut = 'VIP' THEN 100
              WHEN U.Ustatut = 'VVIP' THEN 200
          END
      )
      AND E.Etype IN ('Concert', 'SousEvenement') -- Préférences utilisateur
    ORDER BY E.Ejour, E.Eheure; -- Trier par date
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
    jour INT;
    heure INT;
BEGIN
    -- Vérification de la disponibilité du billet
    SELECT Bdisponibilite INTO billet_disponible
    FROM Billet
    WHERE Bid = billet_id
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

    -- Verifier le nombre de pré-réservations
    IF (SELECT COUNT(*)
        FROM Reservation
        WHERE Uemail = user_email
          AND Rstatut = 'Pre-reserve') >= nb_max_billets THEN
        RAISE EXCEPTION 'Limite de pré-réservations atteinte pour l''utilisateur %', user_email;
    END IF;

    -- Mettre à jour la disponibilité du billet
    UPDATE Billet
    SET Bdisponibilite = FALSE
    WHERE Bid = billet_id;

    -- Récupérer le jour et l'heure actuels
    SELECT jour, heure INTO jour, heure
    FROM TEMPS LIMIT 1;

    -- Insertion de la pré-réservation
    INSERT INTO Reservation (Uemail, Bid, Rjour_debut, Rheure_debut, Rstatut)
    VALUES (user_email, billet_id, jour, heure, 'Pre-reserve');
END;
$$ LANGUAGE plpgsql;

-- Fonction pour confirmer une réservation
-- Cette fonction met à jour le statut de la réservation et le prix d'achat
-- dans la table Billet.
CREATE OR REPLACE FUNCTION confirmer_reservation(
    user_email VARCHAR(255),
    billet_id TEXT
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
      AND Rstatut = 'Pre-reserve'
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Aucune réservation trouvée pour le billet %', billet_id;
    END IF;

    -- Vérification de la disponibilité du billet
    SELECT Bdisponibilite INTO billet_disponible
    FROM Billet
    WHERE Bid = billet_id
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

    -- Mettre à jour le prix d'achat du billet
    UPDATE Billet
    SET Bprix_achat = prix_achat,
        Bdisponibilite = FALSE
    WHERE Bid = billet_id;
END;
$$ LANGUAGE plpgsql;

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
      AND Rstatut = 'Reserve'
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
    SELECT jour, heure INTO jour, heure
    FROM TEMPS LIMIT 1;

    IF statut_utilisateur IS NULL THEN
        RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
    END IF;

    -- Récupérer le nombre de connexions actives
    SELECT COUNT(*) INTO connexions_actuelles
    FROM CreneauConnexionUtilisateur
    WHERE CCjour_debut = jour
    AND CCheure_debut = heure;

    SELECT COALESCE(SUM(max_connexions), 0) INTO max_server_connexions
    FROM CreneauConnexion
    WHERE CCjour_debut = jour
      AND CCheure_debut = heure
      AND (CCetat = 'Ouvert' OR CCetat = 'En attente');


    SELECT max_connexions INTO max_connexions_actif
    FROM CreneauConnexion
    WHERE CCjour_debut = jour
      AND CCheure_debut = heure
      AND CCetat = 'Ouvert';

    IF connexions_actuelles >= max_server_connexions THEN
        INSERT INTO CreneauConnexionUtilisateur (CCjour_debut, CCheure_debut, Uemail, CCetat)
        VALUES (jour, heure, user_email, 'Ferme');
        RAISE EXCEPTION 'Charge système maximale atteinte. Veuillez réessayer plus tard.'; 
    ELSEIF connexions_actuelles >= max_connexions_actif THEN
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

CREATE OR REPLACE FUNCTION connexion_utilisateur(
    user_email VARCHAR(255)
)
RETURNS VOID AS $$
BEGIN
    -- Vérifier si l'utilisateur existe
    IF NOT EXISTS (
        SELECT 1
        FROM Utilisateur
        WHERE Uemail = user_email
    ) THEN
        RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
    END IF;

    SELECT gerer_creneau_connexion(user_email);

    -- Mettre à jour le statut de l'utilisateur à connecté
    UPDATE Utilisateur
    SET Uconnecte = TRUE
    WHERE Uemail = user_email;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION deconnexion_utilisateur(
    user_email VARCHAR(255)
)
RETURNS VOID AS $$
BEGIN
    -- Vérifier si l'utilisateur existe
    IF NOT EXISTS (
        SELECT 1
        FROM Utilisateur
        WHERE Uemail = user_email
    ) THEN
        RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
    END IF;

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
    SET jour = jour + 1;

    -- Réinitialiser l'heure à 0
    UPDATE TEMPS
    SET heure = 0;
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
    RETURN nom_complet || '_' || jour || '_' || heure || '_' || num_salle;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION evenement_prive(
    nom_complet TEXT,
    jour INT,
    heure INT,
    num_salle INT,
    jour_reservation INT,
    heure_reservation INT   
)
RETURNS VOID AS $$
DECLARE
    evenement_id TEXT;
    jour INT;
    heure INT;
BEGIN
    SELECT jour, heure INTO jour, heure
    FROM TEMPS LIMIT 1;
    
    SELECT Enom_complet INTO evenement_id
    FROM Evenement
    WHERE Enom_complet = nom_complet
      AND Ejour = jour
      AND Eheure = heure
      AND Enum_salle = num_salle;

    IF evenement_id IS NULL THEN
        RAISE EXCEPTION 'Événement % non trouvé', nom_complet;
    END IF;

    evenement_id := generer_id_evenement(nom_complet, jour, heure, num_salle);

    INSERT INTO CreneauConnexion (CCjour_debut, CCheure_debut, CCetat, CCmax_connexions)
    VALUES (jour_reservation, heure_reservation, evenement_id, 50);
END;
$$ LANGUAGE plpgsql;
