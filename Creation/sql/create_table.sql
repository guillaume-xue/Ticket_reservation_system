CREATE TABLE Utilisateur (
    Uemail VARCHAR(255) UNIQUE NOT NULL,
    Unom VARCHAR(64) NOT NULL,
    Uprenom VARCHAR(64) NOT NULL,
    Ustatut VARCHAR(255) NOT NULL,
    Unb_max_billets INT NOT NULL,
    Ususpect BOOLEAN NOT NULL DEFAULT FALSE,
    Uconnecte BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (Uemail),
    CHECK (Ustatut IN ('Normal', 'VIP', 'VVIP')),
    CHECK (Unb_max_billets > 0)
);

CREATE TABLE CreneauConnexion (
    CCjour_debut INT NOT NULL,
    CCheure_debut INT NOT NULL,
    CCetat TEXT NOT NULL,
    CCmax_connexions INT NOT NULL,
    PRIMARY KEY (CCjour_debut, CCheure_debut, CCetat),
    CHECK (CCjour_debut >= 0 AND CCheure_debut >= 0)
);

CREATE TABLE Billet (
    Bid TEXT NOT NULL,
    Bjour_achat INT,
    Bheure_achat INT,
    Bprix_initial DECIMAL(10, 2) NOT NULL,
    Bprix_achat DECIMAL(10, 2),
    Bpromotion INT NOT NULL,
    Bdisponibilite BOOLEAN NOT NULL,
    Bnum_place INT,
    PRIMARY KEY (Bid),
    CHECK (Bprix_achat > 0),
    CHECK (Bprix_initial > 0),
    CHECK (Bpromotion >= 0 AND Bpromotion <= 100)
);

CREATE TABLE PolitiqueEtablissement (
    PEtitre VARCHAR(255) NOT NULL PRIMARY KEY,
    description TEXT NOT NULL
);

CREATE TABLE Etablissement (
    ETAadresse VARCHAR(255) NOT NULL,
    ETAnom VARCHAR(255) NOT NULL,
    PRIMARY KEY (ETAadresse, ETAnom)
);

CREATE TABLE Categorie (
    CATnom VARCHAR(255) NOT NULL,
    CATprix DECIMAL(10, 2) NOT NULL,
    CATnb_place INT NOT NULL,
    PRIMARY KEY (CATnom),
    CHECK (CATprix > 0),
    CHECK (CATnb_place > 0)
);

CREATE TABLE Evenement (
    Enom_complet TEXT NOT NULL,
    Enom_film VARCHAR(255) NOT NULL,
    Ejour INT NOT NULL,
    Eheure INT NOT NULL,
    Enum_salle INT NOT NULL,
    Edescription TEXT NOT NULL,
    Etype VARCHAR(32) NOT NULL,
    Eid_parent TEXT,
    PRIMARY KEY (Enom_complet, Ejour, Eheure, Enum_salle),
    CHECK (Etype IN ('Concert', 'SousEvenement', 'Film')),
    CHECK (Enum_salle > 0)
);

-- Relations
CREATE TABLE Echange (
    Uemail_emetteur VARCHAR(255) NOT NULL,
    Uemail_destinataire VARCHAR(255),
    Bid TEXT NOT NULL,
    ECjour INT NOT NULL,
    ECheure INT NOT NULL,
    ECprix DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (Uemail_emetteur) REFERENCES Utilisateur(Uemail),
    FOREIGN KEY (Uemail_destinataire) REFERENCES Utilisateur(Uemail),
    FOREIGN KEY (Bid) REFERENCES Billet(Bid),
    PRIMARY KEY (Uemail_emetteur, ECjour, ECheure, Bid)
);

CREATE TABLE Reservation (
    Uemail VARCHAR(255) NOT NULL,
    Bid TEXT NOT NULL,
    Rjour_debut INT NOT NULL,
    Rheure_debut INT NOT NULL,
    Rstatut VARCHAR(255) NOT NULL,
    FOREIGN KEY (Uemail) REFERENCES Utilisateur(Uemail),
    FOREIGN KEY (Bid) REFERENCES Billet(Bid),
    PRIMARY KEY (Uemail, Bid),
    CHECK (Rstatut IN ('Pre-reserve', 'Reserve', 'Annule', 'Confirme', 'Termine'))
);

CREATE TABLE CreneauConnexionUtilisateur (
    CCjour_debut INT NOT NULL,
    CCheure_debut INT NOT NULL,
    CCetat TEXT NOT NULL,
    Uemail VARCHAR(255) NOT NULL,
    FOREIGN KEY (CCjour_debut, CCheure_debut, CCetat) REFERENCES CreneauConnexion(CCjour_debut, CCheure_debut, CCetat),
    FOREIGN KEY (Uemail) REFERENCES Utilisateur(Uemail),
    PRIMARY KEY (CCjour_debut, CCheure_debut, Uemail, CCetat)
);

CREATE TABLE CreneauConnexionEvenement (
    CCjour_debut INT NOT NULL,
    CCheure_debut INT NOT NULL,
    CCetat TEXT NOT NULL,
    Enom_complet TEXT NOT NULL,
    Ejour INT NOT NULL,
    Eheure INT NOT NULL,
    Enum_salle INT NOT NULL,
    FOREIGN KEY (CCjour_debut, CCheure_debut, CCetat) REFERENCES CreneauConnexion(CCjour_debut, CCheure_debut, CCetat),
    FOREIGN KEY (Enom_complet, Ejour, Eheure, Enum_salle) REFERENCES Evenement(Enom_complet, Ejour, Eheure, Enum_salle),
    PRIMARY KEY (CCjour_debut, CCheure_debut, CCetat, Enom_complet, Ejour, Eheure, Enum_salle)
);

CREATE TABLE BilletEvenement (
    Bid TEXT NOT NULL,
    Enom_complet TEXT NOT NULL,
    Ejour INT NOT NULL,
    Eheure INT NOT NULL,
    Enum_salle INT NOT NULL,
    FOREIGN KEY (Bid) REFERENCES Billet(Bid),
    FOREIGN KEY (Enom_complet, Ejour, Eheure, Enum_salle) REFERENCES Evenement(Enom_complet, Ejour, Eheure, Enum_salle),
    PRIMARY KEY (Bid, Enom_complet, Ejour, Eheure, Enum_salle)
);

CREATE TABLE EtablissementPolitique (
    ETAadresse VARCHAR(255) NOT NULL,
    ETAnom VARCHAR(255) NOT NULL,
    PEtitre VARCHAR(255) NOT NULL,
    FOREIGN KEY (ETAadresse, ETAnom) REFERENCES Etablissement(ETAadresse, ETAnom),
    FOREIGN KEY (PEtitre) REFERENCES PolitiqueEtablissement(PEtitre),
    PRIMARY KEY (ETAadresse, ETAnom, PEtitre)
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
    Enom_complet TEXT NOT NULL,
    Ejour INT NOT NULL,
    Eheure INT NOT NULL,
    Enum_salle INT NOT NULL,
    FOREIGN KEY (CATnom) REFERENCES Categorie(CATnom),
    FOREIGN KEY (Enom_complet, Ejour, Eheure, Enum_salle) REFERENCES Evenement(Enom_complet, Ejour, Eheure, Enum_salle),
    PRIMARY KEY (CATnom, Enom_complet, Ejour, Eheure, Enum_salle)
);

CREATE TABLE EvenementEtablissement (
    Enom_complet TEXT NOT NULL,
    Ejour INT NOT NULL,
    Eheure INT NOT NULL,
    Enum_salle INT NOT NULL,
    ETAadresse VARCHAR(255) NOT NULL,
    ETAnom VARCHAR(255) NOT NULL,
    FOREIGN KEY (Enom_complet, Ejour, Eheure, Enum_salle) REFERENCES Evenement(Enom_complet, Ejour, Eheure, Enum_salle),
    FOREIGN KEY (ETAadresse, ETAnom) REFERENCES Etablissement(ETAadresse, ETAnom),
    PRIMARY KEY (Enom_complet, Ejour, Eheure, Enum_salle, ETAadresse, ETAnom)
);

CREATE TABLE TEMPS (
    jour INT NOT NULL,
    heure INT NOT NULL CHECK (heure >= 0 AND heure < 24)
);

-- Accélérer les recherches sur les réservations par date/heure
CREATE INDEX idx_reservation_jour_heure ON Reservation (Rjour_debut, Rheure_debut);

-- Accélérer les recherches sur les créneaux de connexion par date/heure
CREATE INDEX idx_creneau_connexion_jour_heure ON CreneauConnexion (CCjour_debut, CCheure_debut);

-- Accélérer les recherches sur les événements par nom complet et date
CREATE INDEX idx_evenement_nom_date ON Evenement (Enom_complet, Ejour, Eheure);

-- Accélérer les recherches sur les réservations par statut
CREATE INDEX idx_reservation_email_billet_id ON Reservation (Uemail, Bid);

-- Accélérer les recherches sur la disponibilité des billets
CREATE INDEX idx_billet_disponibilite ON Billet (Bdisponibilite);