CREATE TABLE Utilisateur (
    Uemail VARCHAR(255) UNIQUE NOT NULL,
    Unom VARCHAR(64) NOT NULL,
    Uprenom VARCHAR(64) NOT NULL,
    Ustatut VARCHAR(255) NOT NULL,
    Unb_max_billets INT NOT NULL,
    Ususpect BOOLEAN NOT NULL,
    Uconnecte BOOLEAN NOT NULL,
    PRIMARY KEY (Uemail),
    CHECK (Ustatut IN ('Normal', 'VIP', 'VVIP')),
    CHECK (Unb_max_billets > 0)
);

CREATE TABLE CreneauConnexion (
    CCdate_heure_debut TIMESTAMP NOT NULL,
    CCdate_heure_fin TIMESTAMP NOT NULL,
    CCetat VARCHAR(255) NOT NULL,
    PRIMARY KEY (CCdate_heure_debut, CCdate_heure_fin),
    CHECK (CCetat IN ('Ouvert', 'Ferme', 'En attente')),
    CHECK (CCdate_heure_debut >= CURRENT_TIMESTAMP),
    CHECK (CCdate_heure_fin > CCdate_heure_debut)

);

CREATE TABLE Billet (
    Bid TEXT NOT NULL,
    Bdate_achat TIMESTAMP,
    Bprix_initial DECIMAL(10, 2) NOT NULL,
    Bprix_achat DECIMAL(10, 2),
    Bpromotion INT NOT NULL,
    Bdisponibilite BOOLEAN NOT NULL,
    PRIMARY KEY (Bid),
    CHECK (Bprix_achat > 0),
    CHECK (Bprix_initial > 0),
    CHECK (Bpromotion >= 0 AND Bpromotion <= 100)
);

CREATE TABLE PolitiqueEtablissement (
    PEtitre VARCHAR(255) NOT NULL,
    description TEXT NOT NULL
);

CREATE TABLE Etablissement (
    ETAadresse VARCHAR(255) NOT NULL,
    ETAnom VARCHAR(255) NOT NULL,
    PRIMARY KEY (ETAadresse)
);

CREATE TABLE Categorie (
    CATnom VARCHAR(255) NOT NULL,
    CATprix DECIMAL(10, 2) NOT NULL,
    CATnum_place INT NOT NULL,
    PRIMARY KEY (Cnom)
    CHECK (CATprix > 0),
    CHECK (CATnum_place > 0)
);

CREATE TABLE Evenement (
    Eid TEXT NOT NULL,
    Enom VARCHAR(255) NOT NULL,
    Edate TIMESTAMP NOT NULL,
    Enum_salle INT NOT NULL,
    Edescription TEXT NOT NULL,
    Etype VARCHAR(32) NOT NULL,
    PRIMARY KEY (Eid)
    CHECK (Etype IN ('Concert', 'SousEvenement', 'Film'))
    CHECK (Enum_salle > 0)
);

-- Relations
CREATE TABLE Echange (
    Uemail_emetteur VARCHAR(255) NOT NULL,
    Uemail_destinataire VARCHAR(255) NOT NULL,
    Edate TIMESTAMP NOT NULL,
    FOREIGN KEY (Uemail_emetteur) REFERENCES Utilisateur(Uemail),
    FOREIGN KEY (Uemail_destinataire) REFERENCES Utilisateur(Uemail),
    PRIMARY KEY (Uemail_emetteur, Uemail_destinataire, Edate)
)

CREATE TABLE Achat (
    Uemail VARCHAR(255) NOT NULL,
    Bid TEXT NOT NULL,
    Adate TIMESTAMP NOT NULL,
    FOREIGN KEY (Uemail) REFERENCES Utilisateur(Uemail),
    FOREIGN KEY (Bid) REFERENCES Billet(Bid),
    PRIMARY KEY (Uemail, Bid)
);

CREATE TABLE Reservation (
    Uemail VARCHAR(255) NOT NULL,
    Bid TEXT NOT NULL,
    Rdate_heure_debut TIMESTAMP NOT NULL,
    Rdate_heure_fin TIMESTAMP NOT NULL,
    Rstatut VARCHAR(255) NOT NULL,
    FOREIGN KEY (Uemail) REFERENCES Utilisateur(Uemail),
    FOREIGN KEY (Bid) REFERENCES Billet(Bid),
    PRIMARY KEY (Uemail, Bid),
    CHECK (Retat IN ('Pré-réservé', 'Réservé', 'Annulé', 'Confirmé')),
);

CREATE TABLE CreneauConnexionUtilisateurBillet (
    CCdate_heure_debut TIMESTAMP NOT NULL,
    Uemail VARCHAR(255) NOT NULL,
    Bid TEXT NOT NULL,
    FOREIGN KEY (CCdate_heure_debut) REFERENCES CreneauConnexion(CCdate_heure_debut),
    FOREIGN KEY (Uemail) REFERENCES Utilisateur(Uemail),
    FOREIGN KEY (Bid) REFERENCES Billet(Bid),
    PRIMARY KEY (CCdate_heure_debut, Uemail, Bid)
);

CREATE TABLE EtablissementPolitique (
    ETAadresse VARCHAR(255) NOT NULL,
    PEtitre VARCHAR(255) NOT NULL,
    FOREIGN KEY (ETAadresse) REFERENCES Etablissement(ETAadresse),
    FOREIGN KEY (PEtitre) REFERENCES PolitiqueEtablissement(PEtitre),
    PRIMARY KEY (ETAadresse, PEtitre)
);

CREATE TABLE CategorieBillet (
    CATnom VARCHAR(255) NOT NULL,
    Bid TEXT NOT NULL,
    FOREIGN KEY (CATnom) REFERENCES Categorie(CATnom),
    FOREIGN KEY (Bid) REFERENCES Billet(Bid),
    PRIMARY KEY (CATnom, Bid)
);

CREATE TABLE CategorieEvenement (
    CATnom VARCHAR(255) NOT NULL,
    Eid TEXT NOT NULL,
    FOREIGN KEY (CATnom) REFERENCES Categorie(CATnom),
    FOREIGN KEY (Eid) REFERENCES Evenement(Eid),
    PRIMARY KEY (CATnom, Eid)
);

CREATE TABLE EvenementEtablissement (
    Eid TEXT NOT NULL,
    ETAadresse VARCHAR(255) NOT NULL,
    FOREIGN KEY (Eid) REFERENCES Evenement(Eid),
    FOREIGN KEY (ETAadresse) REFERENCES Etablissement(ETAadresse),
    PRIMARY KEY (Eid, ETAadresse)
);

CREATE TABLE TEMPS (
    jour INTEGER NOT NULL,
    heure INTEGER NOT NULL CHECK (heure >= 0 AND heure < 24)
);