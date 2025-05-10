-- -- Suppression des scénarios de test
-- DROP FUNCTION IF EXISTS recuperer_evenements_disponibles(VARCHAR) CASCADE;
-- DROP FUNCTION IF EXISTS pre_reserver_billet(VARCHAR,TEXT,INT,INT,INT,INT) CASCADE;
-- DROP FUNCTION IF EXISTS confirmer_reservation(VARCHAR,TEXT,DECIMAL) CASCADE;
-- DROP FUNCTION IF EXISTS annuler_reservation(VARCHAR,TEXT) CASCADE;
-- DROP FUNCTION IF EXISTS verifier_comportements_suspects() CASCADE;
-- DROP FUNCTION IF EXISTS gerer_creneau_connexion(VARCHAR,INT,INT,INT,INT) CASCADE;
-- DROP FUNCTION IF EXISTS gerer_connexion_et_verifier_suspects(VARCHAR,INT,INT,INT,INT) CASCADE;
-- DROP FUNCTION IF EXISTS gerer_reservation_automatique(VARCHAR,TEXT,INT,INT,INT,INT) CASCADE;

-- -- Suppression des triggers
-- DROP TRIGGER IF EXISTS controle_temps_trigger ON TEMPS;
-- DROP TRIGGER IF EXISTS calcul_nb_max_billets_trigger ON Utilisateur;

-- -- Suppression des fonctions
-- DROP FUNCTION IF EXISTS controle_temps() CASCADE;
-- DROP FUNCTION IF EXISTS calcul_nb_max_billets() CASCADE;
-- DROP FUNCTION IF EXISTS inserer_evenement(TEXT, VARCHAR, INT, INT, INT, INT, INT, TEXT, VARCHAR) CASCADE;
-- DROP FUNCTION IF EXISTS generer_id_billet() CASCADE;
-- DROP FUNCTION IF EXISTS creer_billet(DECIMAL) CASCADE;
-- DROP FUNCTION IF EXISTS creer_billets(DECIMAL, INT) CASCADE;

-- -- Suppression des séquences
-- DROP SEQUENCE IF EXISTS billet_seq CASCADE;

-- -- Suppression des tables (déjà présent)
-- DROP TABLE IF EXISTS TEMPS CASCADE;
-- DROP TABLE IF EXISTS EvenementEtablissement CASCADE;
-- DROP TABLE IF EXISTS CategorieEvenement CASCADE;
-- DROP TABLE IF EXISTS CategorieBillet CASCADE;
-- DROP TABLE IF EXISTS EtablissementPolitique CASCADE;
-- DROP TABLE IF EXISTS CreneauConnexionBillet CASCADE;
-- DROP TABLE IF EXISTS CreneauConnexionUtilisateur CASCADE;
-- DROP TABLE IF EXISTS Reservation CASCADE;
-- DROP TABLE IF EXISTS Achat CASCADE;
-- DROP TABLE IF EXISTS Echange CASCADE;
-- DROP TABLE IF EXISTS Evenement CASCADE;
-- DROP TABLE IF EXISTS Categorie CASCADE;
-- DROP TABLE IF EXISTS Etablissement CASCADE;
-- DROP TABLE IF EXISTS PolitiqueEtablissement CASCADE;
-- DROP TABLE IF EXISTS Billet CASCADE;
-- DROP TABLE IF EXISTS CreneauConnexion CASCADE;
-- DROP TABLE IF EXISTS Utilisateur CASCADE;

DROP SCHEMA public CASCADE;
CREATE SCHEMA public;