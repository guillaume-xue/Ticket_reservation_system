-- Fonction pour récupérer les événements disponibles pour un utilisateur
CREATE OR REPLACE FUNCTION recuperer_evenements_disponibles(
    user_email VARCHAR(255)
)
RETURNS TABLE (
    evenement_id TEXT,
    nom_evenement VARCHAR(255),
    date_evenement TIMESTAMP,
    description_evenement TEXT,
    type_evenement VARCHAR(32)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        E.Eid AS evenement_id,
        E.Enom AS nom_evenement,
        E.Edate AS date_evenement,
        E.Edescription AS description_evenement,
        E.Etype AS type_evenement
    FROM Evenement E
    JOIN CategorieEvenement CE ON E.Eid = CE.Eid
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
    ORDER BY E.Edate; -- Trier par date
END;
$$ LANGUAGE plpgsql;

-- Fonction pour pré-réserver un billet
-- Cette fonction vérifie la disponibilité du billet et l'associe à l'utilisateur
-- en mettant à jour la table Billet et en insérant une nouvelle réservation
-- dans la table Reservation.
CREATE OR REPLACE FUNCTION pre_reserver_billet(
    user_email VARCHAR(255),
    billet_id TEXT,
    creneau_debut TIMESTAMP,
    creneau_fin TIMESTAMP
)
RETURNS VOID AS $$
DECLARE
    nb_max_billets INT;
    billet_disponible BOOLEAN;
BEGIN
    -- Vérification de la disponibilité du billet
    SELECT Bdisponibilite INTO billet_disponible
    FROM Billet
    WHERE Bid = billet_id;

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

    -- Insertion de la pré-réservation
    INSERT INTO Reservation (Uemail, Bid, Rdate_heure_debut, Rdate_heure_fin,
                             Rstatut)
    VALUES (user_email, billet_id, creneau_debut, creneau_fin, 'Pre-reserve');
END;
$$ LANGUAGE plpgsql;

-- Fonction pour confirmer une réservation
-- Cette fonction met à jour le statut de la réservation et le prix d'achat
-- dans la table Billet.
CREATE OR REPLACE FUNCTION confirmer_reservation(
    user_email VARCHAR(255),
    billet_id TEXT,
    prix_achat DECIMAL(10, 2)
)
RETURNS VOID AS $$
BEGIN
    -- Vérification de l'existence de la réservation
    IF NOT EXISTS (
        SELECT 1
        FROM Reservation
        WHERE Uemail = user_email
          AND Bid = billet_id
          AND Rstatut = 'Pre-reserve'
    ) THEN
        RAISE EXCEPTION 'Aucune réservation trouvée pour le billet %', billet_id;
    END IF;

    -- Mettre à jour le statut de la réservation et le prix d'achat
    UPDATE Reservation
    SET Rstatut = 'Confirme',
        Rprix_achat = prix_achat
    WHERE Uemail = user_email
      AND Bid = billet_id;

    -- Mettre à jour le prix d'achat du billet
    UPDATE Billet
    SET Bprix_achat = prix_achat,
        Bdisponibilite = TRUE -- Le billet est maintenant disponible après confirmation
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
BEGIN
    -- Vérification de l'existence de la réservation
    IF NOT EXISTS (
        SELECT 1
        FROM Reservation
        WHERE Uemail = user_email
          AND Bid = billet_id
          AND Rstatut = 'Pre-reserve'
    ) THEN
        RAISE EXCEPTION 'Aucune réservation trouvée pour le billet %', billet_id;
    END IF;

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

-- Fonction pour vérifier les comportements suspects des utilisateurs
-- Cette fonction met à jour la colonne Ususpect dans la table Utilisateur
-- et retourne une liste des utilisateurs suspects avec leurs statistiques.
-- Les critères de suspicion incluent :
-- - Plus de 10 annulations
-- - Plus de 50 réservations
-- - Durée moyenne de réservation inférieure à 1 heure
-- - Réservations concentrées sur une journée
CREATE OR REPLACE FUNCTION verifier_comportements_suspects()
RETURNS TABLE (
    utilisateur_email VARCHAR(255),
    nombre_reservations INT,
    nombre_annulations INT,
    nombre_pre_reservations INT,
    nombre_confirmations INT,
    duree_moyenne_reservation_heures DECIMAL(10, 2),
    derniere_reservation TIMESTAMP,
    premiere_reservation TIMESTAMP
) AS $$
BEGIN
    -- Mettre à jour la colonne Ususpect pour les utilisateurs suspects
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
            OR AVG(EXTRACT(EPOCH FROM (R.Rdate_heure_fin - R.Rdate_heure_debut))) / 3600 < 1 -- Durée moyenne < 1 heure
            OR MAX(R.Rdate_heure_debut) - MIN(R.Rdate_heure_debut) < INTERVAL '1 day' -- Réservations concentrées sur une journée
    );

    -- Retourner la liste des utilisateurs suspects avec leurs statistiques
    RETURN QUERY
    SELECT 
        U.Uemail AS utilisateur_email,
        COUNT(R.Bid) AS nombre_reservations,
        COUNT(CASE WHEN R.Rstatut = 'Annule' THEN 1 END) AS nombre_annulations,
        COUNT(CASE WHEN R.Rstatut = 'Pre-reserve' THEN 1 END) AS nombre_pre_reservations,
        COUNT(CASE WHEN R.Rstatut = 'Confirme' THEN 1 END) AS nombre_confirmations,
        AVG(EXTRACT(EPOCH FROM (R.Rdate_heure_fin - R.Rdate_heure_debut))) / 3600 AS duree_moyenne_reservation_heures,
        MAX(R.Rdate_heure_debut) AS derniere_reservation,
        MIN(R.Rdate_heure_debut) AS premiere_reservation
    FROM Reservation R
    JOIN Utilisateur U ON R.Uemail = U.Uemail
    GROUP BY U.Uemail
    HAVING 
        COUNT(CASE WHEN R.Rstatut = 'Annule' THEN 1 END) > 10 -- Plus de 10 annulations
        OR COUNT(R.Bid) > 50 -- Plus de 50 réservations
        OR AVG(EXTRACT(EPOCH FROM (R.Rdate_heure_fin - R.Rdate_heure_debut))) / 3600 < 1 -- Durée moyenne < 1 heure
        OR MAX(R.Rdate_heure_debut) - MIN(R.Rdate_heure_debut) < INTERVAL '1 day'; -- Réservations concentrées sur une journée
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION gerer_creneau_connexion(
    user_email VARCHAR(255),
    date_debut TIMESTAMP,
    date_fin TIMESTAMP
)
RETURNS BOOLEAN AS $$
DECLARE
    statut_utilisateur VARCHAR(255);
    connexions_actuelles INT;
    max_connexions INT;
    connexions_utilisateur INT;
BEGIN
    -- Récupérer le statut de l'utilisateur
    SELECT Ustatut INTO statut_utilisateur
    FROM Utilisateur
    WHERE Uemail = user_email;

    IF statut_utilisateur IS NULL THEN
        RAISE EXCEPTION 'Utilisateur % non trouvé', user_email;
    END IF;

    -- Récupérer le nombre de connexions actives
    SELECT COUNT(*) INTO connexions_actuelles
    FROM Utilisateur
    WHERE Uconnecte = TRUE;

    -- Vérifier la charge système (limiter à 100 connexions simultanées)
    SELECT max_connexions INTO max_connexions
    FROM CreneauConnexion
    WHERE CCdate_heure_debut <= CURRENT_TIMESTAMP
      AND CCdate_heure_fin >= CURRENT_TIMESTAMP;

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
      AND CCdate_heure_fin > CURRENT_TIMESTAMP;

    IF connexions_utilisateur >= 3 THEN
        RAISE EXCEPTION 'Utilisateur % a atteint la limite de connexions actives.', user_email;
    END IF;

    -- Insérer le créneau de connexion
    INSERT INTO CreneauConnexion (CCdate_heure_debut, CCdate_heure_fin, CCetat)
    VALUES (date_debut, date_fin, 'Ouvert');

    -- Mettre à jour le statut de l'utilisateur
    UPDATE Utilisateur
    SET Uconnecte = TRUE
    WHERE Uemail = user_email;

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;