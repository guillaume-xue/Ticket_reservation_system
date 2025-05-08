#!/bin/bash

psql -U xiao -d bddavancee -f Creation/sql/drop_all_tables.sql

echo "Terminé."