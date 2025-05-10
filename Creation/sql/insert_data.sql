\copy Utilisateur (Unom, Uprenom, Uemail, Ustatut) FROM './Creation/csv/users.csv' DELIMITER ',' CSV HEADER;
\copy PolitiqueEtablissement (PEtitre, description) FROM './Creation/csv/politique_etablissement.csv' DELIMITER ',' CSV HEADER;
\copy Etablissement (ETAadresse, ETAnom) FROM './Creation/csv/etablissements.csv' DELIMITER ',' CSV HEADER;
\copy Categorie (CATnom, CATprix, CATnb_place) FROM './Creation/csv/categories.csv' DELIMITER ',' CSV HEADER;
-- \copy Evenement (Eid, Enom, Ejour, Eheure, Enum_salle, Edescription, Etype) FROM './Creation/csv/evenement.csv' DELIMITER ',' CSV HEADER;
SELECT inserer_evenement('Top Gun avant premiere', 'Top Gun', 2, 20, 1, 'Film Top Gun', 'Film', 'Paris', 'Grand Rex');
SELECT inserer_evenement('Top Gun vip', 'Top Gun', 2, 20, 1, 'Film Top Gun', 'SousEvenement', 'Paris', 'Grand Rex');
SELECT inserer_evenement('Opera', 'Opera', 5, 20, 1, 'Opera de Paris', 'Concert', 'Paris', 'Grand Rex');

INSERT INTO TEMPS (jour, heure) VALUES (0,0);

