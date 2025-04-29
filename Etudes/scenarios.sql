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