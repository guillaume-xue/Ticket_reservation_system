-- Trigger to control the insertion and update of the TEMPS table
CREATE TRIGGER controle_temps_trigger BEFORE UPDATE OR INSERT ON TEMPS
FOR EACH ROW
EXECUTE PROCEDURE controle_temps();