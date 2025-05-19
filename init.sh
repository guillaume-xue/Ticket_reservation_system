#!/bin/bash

psql -U xiao -d bddavancee -f Creation/sql/create_table.sql
psql -U xiao -d bddavancee -f Creation/sql/create_triggers.sql
psql -U xiao -d bddavancee -f Etudes/scenarios.sql
psql -U xiao -d bddavancee -f Etudes/affichages.sql
psql -U xiao -d bddavancee -f Creation/sql/insert_data.sql

echo "Terminé."