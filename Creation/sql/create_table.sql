CREATE TABLE Utilisateur (
    id_utilisateur SERIAL PRIMARY KEY,
    nom VARCHAR(255) NOT NULL,
    prenom VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL
);

CREATE TABLE StatutUtilisateur (
    id_statut SERIAL PRIMARY KEY,
    description TEXT NOT NULL,
    date_expiration DATE
);

CREATE TABLE Avantage (
    id_avantage SERIAL PRIMARY KEY,
    description TEXT NOT NULL,
    date_expiration DATE
);

CREATE TABLE HistoriqueTransaction (
    id_transaction SERIAL PRIMARY KEY,
    action VARCHAR(255) NOT NULL,
    attente BOOLEAN NOT NULL,
    fait BOOLEAN NOT NULL
);

CREATE TABLE CreneauConnexion (
    id_creneau SERIAL PRIMARY KEY,
    date TIMESTAMP NOT NULL
);

CREATE TABLE PreReservation (
    id_prereservation SERIAL PRIMARY KEY,
    date TIMESTAMP NOT NULL
);

CREATE TABLE Billet (
    id_billet SERIAL PRIMARY KEY,
    date_achat TIMESTAMP NOT NULL
);

CREATE TABLE PolitiqueEtablissement (
    id_politique SERIAL PRIMARY KEY,
    description TEXT NOT NULL
);

CREATE TABLE Etablissement (
    id_etablissement SERIAL PRIMARY KEY,
    nom VARCHAR(255) NOT NULL
);

CREATE TABLE Seance (
    id_seance SERIAL PRIMARY KEY,
    date TIMESTAMP NOT NULL,
    id_etablissement INT NOT NULL,
    FOREIGN KEY (id_etablissement) REFERENCES Etablissement(id_etablissement)
);

CREATE TABLE Categorie (
    id_categorie SERIAL PRIMARY KEY,
    nom VARCHAR(255) NOT NULL
);

CREATE TABLE Evenement (
    id_evenement SERIAL PRIMARY KEY,
    nom VARCHAR(255) NOT NULL
);

CREATE TABLE Film (
    id_film SERIAL PRIMARY KEY,
    titre VARCHAR(255) NOT NULL
);

CREATE TABLE Concert (
    id_concert SERIAL PRIMARY KEY,
    artiste VARCHAR(255) NOT NULL
);

CREATE TABLE SousEvenement (
    id_sous_evenement SERIAL PRIMARY KEY,
    nom VARCHAR(255) NOT NULL
);

-- Relations
CREATE TABLE UtilisateurStatut (
    id_utilisateur INT NOT NULL,
    id_statut INT NOT NULL,
    PRIMARY KEY (id_utilisateur, id_statut),
    FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id_utilisateur),
    FOREIGN KEY (id_statut) REFERENCES StatutUtilisateur(id_statut)
);

CREATE TABLE UtilisateurAvantage (
    id_utilisateur INT NOT NULL,
    id_avantage INT NOT NULL,
    PRIMARY KEY (id_utilisateur, id_avantage),
    FOREIGN KEY (id_utilisateur) REFERENCES Utilisateur(id_utilisateur),
    FOREIGN KEY (id_avantage) REFERENCES Avantage(id_avantage)
);

CREATE TABLE BilletSeance (
    id_billet INT NOT NULL,
    id_seance INT NOT NULL,
    PRIMARY KEY (id_billet, id_seance),
    FOREIGN KEY (id_billet) REFERENCES Billet(id_billet),
    FOREIGN KEY (id_seance) REFERENCES Seance(id_seance)
);

CREATE TABLE SeanceCategorie (
    id_seance INT NOT NULL,
    id_categorie INT NOT NULL,
    PRIMARY KEY (id_seance, id_categorie),
    FOREIGN KEY (id_seance) REFERENCES Seance(id_seance),
    FOREIGN KEY (id_categorie) REFERENCES Categorie(id_categorie)
);

CREATE TABLE EvenementSousEvenement (
    id_evenement INT NOT NULL,
    id_sous_evenement INT NOT NULL,
    PRIMARY KEY (id_evenement, id_sous_evenement),
    FOREIGN KEY (id_evenement) REFERENCES Evenement(id_evenement),
    FOREIGN KEY (id_sous_evenement) REFERENCES SousEvenement(id_sous_evenement)
);