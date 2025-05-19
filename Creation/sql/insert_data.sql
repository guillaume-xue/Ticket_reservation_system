\copy Utilisateur (Unom, Uprenom, Uemail, Ustatut) FROM './Creation/csv/users.csv' DELIMITER ',' CSV HEADER;
\copy PolitiqueEtablissement (PEtitre, description) FROM './Creation/csv/politique_etablissement.csv' DELIMITER ',' CSV HEADER;
\copy Etablissement (ETAadresse, ETAnom) FROM './Creation/csv/etablissements.csv' DELIMITER ',' CSV HEADER;
\copy Categorie (CATnom, CATprix, CATnb_place) FROM './Creation/csv/categories.csv' DELIMITER ',' CSV HEADER;
-- \copy Evenement (Eid, Enom, Ejour, Eheure, Enum_salle, Edescription, Etype) FROM './Creation/csv/evenement.csv' DELIMITER ',' CSV HEADER;
-- SELECT inserer_evenement('Top Gun avant premiere', 'Top Gun', 2, 20, 1, 'Film Top Gun', 'Film', 'Paris', 'Grand Rex');
-- SELECT inserer_evenement('Top Gun vip', 'Top Gun', 2, 20, 1, 'Film Top Gun', 'SousEvenement', 'Paris', 'Grand Rex');
-- SELECT inserer_evenement('Opera', 'Opera', 5, 20, 1, 'Opera de Paris', 'Concert', 'Paris', 'Grand Rex');
-- SELECT inserer_evenement('Tom et Jerry Film', 'Tom et Jerry', 5, 20, 1, 'Tom et Jerry', 'Film', 'Paris', 'Grand Rex');
SELECT inserer_evenement('FilmIronMan1', 'IronMan1', 1, 1, 1, 'Un film de super-héros', 'Film', 'Paris', 'Grand Rex');
SELECT inserer_evenement('FilmIronMan1VIP', 'IronMan1', 1, 1, 1, 'Un film de super-héros', 'SousEvenement', 'Paris', 'Grand Rex');
SELECT inserer_evenement('FilmIronMan1', 'IronMan1', 1, 1, 2, 'Un film de super-héros', 'Film', 'Paris', 'Grand Rex');
SELECT inserer_evenement('FilmIronMan1', 'IronMan1', 1, 1, 3, 'Un film de super-héros', 'Film', 'Paris', 'Grand Rex');
SELECT inserer_evenement('FilmIronMan1', 'IronMan1', 1, 3, 1, 'Un film de super-héros', 'Film', 'Paris', 'Grand Rex');
SELECT inserer_evenement('FilmIronMan1', 'IronMan1', 1, 5, 1, 'Un film de super-héros', 'Film', 'Paris', 'Grand Rex');
SELECT inserer_evenement('FilmThor1', 'Thor1', 2, 1, 1, 'Un film de super-héros', 'Film', 'Paris', 'Grand Rex');
SELECT inserer_evenement('FilmThor1VIP', 'Thor1', 2, 1, 1, 'Un film de super-héros', 'SousEvenement', 'Paris', 'Grand Rex');
SELECT inserer_evenement('ConcertGundamVIP', 'Gundam', 3, 1, 1, 'Un anime de mecha', 'Concert', 'Paris', 'Grand Rex');


INSERT INTO TEMPS (jour, heure) VALUES (0,0);

