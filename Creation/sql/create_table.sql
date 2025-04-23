CREATE TABLE Utilisateur (
    Uemail VARCHAR(255) UNIQUE NOT NULL,
    Unom VARCHAR(64) NOT NULL,
    Uprenom VARCHAR(64) NOT NULL,
    Ustatut VARCHAR(255) NOT NULL,
    Unb_max_billets INT NOT NULL,
    PRIMARY KEY (Uemail),
    CHECK (Ustatut IN ('Normal', 'VIP', 'VVIP')),
    CHECK (Unb_max_billets > 0)
);

CREATE TABLE CreneauConnexion (
    CCdate_heure_debut TIMESTAMP NOT NULL,
    CCetat VARCHAR(255) NOT NULL,
    PRIMARY KEY (CCdate_heure_debut)
);

CREATE TABLE Billet (
    Bid TEXT NOT NULL,
    Bprix_final DECIMAL(10, 2) NOT NULL,
    Bpromotion DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (Bid),
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

CREATE TABLE CreneauConnexionBillet (
    CCdate_heure_debut TIMESTAMP NOT NULL,
    Bid TEXT NOT NULL,
    FOREIGN KEY (CCdate_heure_debut) REFERENCES CreneauConnexion(CCdate_heure_debut),
    FOREIGN KEY (Bid) REFERENCES Billet(Bid),
    PRIMARY KEY (CCdate_heure_debut, Bid)
);

CREATE TABLE CreneauConnexionUtilisateur (
    CCdate_heure_debut TIMESTAMP NOT NULL,
    Uemail VARCHAR(255) NOT NULL,
    FOREIGN KEY (CCdate_heure_debut) REFERENCES CreneauConnexion(CCdate_heure_debut),
    FOREIGN KEY (Uemail) REFERENCES Utilisateur(Uemail),
    PRIMARY KEY (CCdate_heure_debut, Uemail)
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