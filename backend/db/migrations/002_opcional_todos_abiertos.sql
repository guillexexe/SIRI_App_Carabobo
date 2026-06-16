-- Si todos sus incidentes quedaron "cerrados" por error y quiere verlos otra vez en el mapa en vivo:
USE proteccion_civil_carabobo;
UPDATE incidentes SET cerrado = 0;
