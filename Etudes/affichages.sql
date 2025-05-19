CREATE OR REPLACE FUNCTION affichage_temps()
RETURNS TABLE(jour INT, heure INT) AS $$
BEGIN
    RETURN QUERY
    SELECT *
    FROM TEMPS;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION affichage_evenement(
    jour INT DEFAULT NULL
)
RETURNS TABLE(Enom_complet TEXT, Ejour INT, Eheure INT, Enum_salle INT) AS $$
DECLARE
    jour_courant INT;
BEGIN
    IF jour IS NULL THEN
        SELECT TEMPS.jour 
        INTO jour_courant
        FROM TEMPS LIMIT 1;

        RETURN QUERY
        SELECT Evenement.Enom_complet, Evenement.Ejour, Evenement.Eheure, Evenement.Enum_salle
        FROM Evenement
        WHERE Evenement.Ejour BETWEEN jour_courant AND jour_courant + 6
        ORDER BY Ejour, Eheure, Enum_salle;
    ELSE
        RETURN QUERY
        SELECT Evenement.Enom_complet, Evenement.Ejour, Evenement.Eheure, Evenement.Enum_salle
        FROM Evenement
        WHERE Evenement.Ejour = jour
        ORDER BY Ejour, Eheure, Enum_salle;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION affichage_evenement_prive(
    jour INT DEFAULT NULL
)
RETURNS TABLE(Enom_complet TEXT, Ejour INT, Eheure INT, Enum_salle INT, CCetat TEXT) AS $$
DECLARE
    jour_courant INT;
BEGIN   
    IF jour IS NULL THEN
        SELECT TEMPS.jour 
        INTO jour_courant
        FROM TEMPS LIMIT 1;

        RETURN QUERY
        SELECT E.Enom_complet, E.Ejour, E.Eheure, E.Enum_salle, CCE.CCetat
        FROM Evenement E
        JOIN CreneauConnexionEvenement CCE
        ON E.Enom_complet = CCE.Enom_complet
        AND E.Ejour = CCE.Ejour
        AND E.Eheure = CCE.Eheure
        AND E.Enum_salle = CCE.Enum_salle
        WHERE E.Ejour BETWEEN jour_courant AND jour_courant + 6
        ORDER BY E.Ejour, E.Eheure, E.Enum_salle;
    ELSE
        RETURN QUERY
        SELECT E.Enom_complet, E.Ejour, E.Eheure, E.Enum_salle, CCE.CCetat
        FROM Evenement E
        JOIN CreneauConnexionEvenement CCE
        ON E.Enom_complet = CCE.Enom_complet
        AND E.Ejour = CCE.Ejour
        AND E.Eheure = CCE.Eheure
        AND E.Enum_salle = CCE.Enum_salle
        ORDER BY E.Ejour, E.Eheure, E.Enum_salle;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION affichage_evenement_prive_utilisateur(
    mail VARCHAR
)
RETURNS TABLE(CCjour_debut INT, CCheure_debut INT, CCetat TEXT, Uemail VARCHAR) AS $$
BEGIN
    RETURN QUERY
    SELECT CCU.CCjour_debut, CCU.CCheure_debut, CCU.CCetat, CCU.Uemail
    FROM CreneauConnexionUtilisateur CCU
    WHERE CCU.Uemail = mail;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION affichage_billets_disponibles(
    jour INT DEFAULT NULL
)
RETURNS TABLE(Bid TEXT, Enom_complet TEXT, Ejour INT, Eheure INT, Enum_salle INT) AS $$
DECLARE
    jour_courant INT;
BEGIN
    IF jour IS NULL THEN
        SELECT TEMPS.jour INTO jour_courant FROM TEMPS LIMIT 1;

        RETURN QUERY
        SELECT B.Bid, BE.Enom_complet, BE.Ejour, BE.Eheure, BE.Enum_salle
        FROM Billet B
        JOIN BilletEvenement BE ON B.Bid = BE.Bid
        LEFT JOIN CreneauConnexionEvenement CCE
            ON BE.Enom_complet = CCE.Enom_complet
            AND BE.Ejour = CCE.Ejour
            AND BE.Eheure = CCE.Eheure
            AND BE.Enum_salle = CCE.Enum_salle
        WHERE B.Bdisponibilite = TRUE
          AND BE.Ejour BETWEEN jour_courant AND jour_courant + 6
          AND CCE.Enom_complet IS NULL -- Exclure les événements privés
        ORDER BY BE.Ejour, BE.Eheure, BE.Enum_salle;
    ELSE
        RETURN QUERY
        SELECT B.Bid, BE.Enom_complet, BE.Ejour, BE.Eheure, BE.Enum_salle
        FROM Billet B
        JOIN BilletEvenement BE ON B.Bid = BE.Bid
        LEFT JOIN CreneauConnexionEvenement CCE
            ON BE.Enom_complet = CCE.Enom_complet
            AND BE.Ejour = CCE.Ejour
            AND BE.Eheure = CCE.Eheure
            AND BE.Enum_salle = CCE.Enum_salle
        WHERE B.Bdisponibilite = TRUE
          AND BE.Ejour = jour
          AND CCE.Enom_complet IS NULL -- Exclure les événements privés
        ORDER BY BE.Ejour, BE.Eheure, BE.Enum_salle;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION affichage_billets_prives(
    jour INT DEFAULT NULL
)
RETURNS TABLE(Bid TEXT, Enom_complet TEXT, Ejour INT, Eheure INT, Enum_salle INT, CCetat TEXT) AS $$
DECLARE
    jour_courant INT;
BEGIN
    IF jour IS NULL THEN
        SELECT TEMPS.jour INTO jour_courant FROM TEMPS LIMIT 1;

        RETURN QUERY
        SELECT B.Bid, BE.Enom_complet, BE.Ejour, BE.Eheure, BE.Enum_salle, CCE.CCetat
        FROM Billet B
        JOIN BilletEvenement BE ON B.Bid = BE.Bid
        JOIN CreneauConnexionEvenement CCE
            ON BE.Enom_complet = CCE.Enom_complet
            AND BE.Ejour = CCE.Ejour
            AND BE.Eheure = CCE.Eheure
            AND BE.Enum_salle = CCE.Enum_salle
        WHERE B.Bdisponibilite = TRUE
          AND BE.Ejour BETWEEN jour_courant AND jour_courant + 6
        ORDER BY BE.Ejour, BE.Eheure, BE.Enum_salle;
    ELSE
        RETURN QUERY
        SELECT B.Bid, BE.Enom_complet, BE.Ejour, BE.Eheure, BE.Enum_salle, CCE.CCetat
        FROM Billet B
        JOIN BilletEvenement BE ON B.Bid = BE.Bid
        JOIN CreneauConnexionEvenement CCE
            ON BE.Enom_complet = CCE.Enom_complet
            AND BE.Ejour = CCE.Ejour
            AND BE.Eheure = CCE.Eheure
            AND BE.Enum_salle = CCE.Enum_salle
        WHERE B.Bdisponibilite = TRUE
          AND BE.Ejour = jour
        ORDER BY BE.Ejour, BE.Eheure, BE.Enum_salle;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION affichage_billets_reserves_utilisateur(
    mail VARCHAR
)
RETURNS TABLE(
    Bid TEXT,
    Rstatut VARCHAR,
    Rjour_debut INT,
    Rheure_debut INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT R.Bid, R.Rstatut, R.Rjour_debut, R.Rheure_debut
    FROM Reservation R
    WHERE R.Uemail = mail
      AND R.Rstatut IN ('Pre-reserve', 'Reserve')
    ORDER BY R.Rjour_debut, R.Rheure_debut, R.Bid;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION affichage_billets_utilisateur(
    mail VARCHAR
)
RETURNS TABLE(
    Bid TEXT,
    Rstatut VARCHAR,
    Rjour_debut INT,
    Rheure_debut INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT R.Bid, R.Rstatut, R.Rjour_debut, R.Rheure_debut
    FROM Reservation R
    WHERE R.Uemail = mail
      AND R.Rstatut IN ('Confirme', 'Termine')
    ORDER BY R.Rjour_debut, R.Rheure_debut, R.Bid;
END;
$$ LANGUAGE plpgsql;