SET statement_timeout = 0;
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET check_function_bodies = false;
SET client_min_messages = warning;

CREATE SCHEMA pr_monitoring_flora_territory;

SET search_path = pr_monitoring_flora_territory, pg_catalog, public;

SET default_with_oids = false;

------------------------
--TABLES AND SEQUENCES--
------------------------

CREATE TABLE t_infos_site (
    id_infos_site serial NOT NULL,
    id_base_site integer NOT NULL,
    cd_nom integer NOT NULL
);
COMMENT ON TABLE pr_monitoring_flora_territory.t_infos_site IS 'Extension de t_base_sites de gn_monitoring, permet d\avoir les infos complémentaires d\un site';


CREATE TABLE cor_visit_grid (
    id_area integer NOT NULL,
    id_base_visit integer NOT NULL,
    presence boolean NOT NULL,
    uuid_base_visit UUID DEFAULT public.uuid_generate_v4() 
);
COMMENT ON TABLE pr_monitoring_flora_territory.cor_visit_grid IS 'Enregistrer la présence/absence d\une espèce dans une maille définie lors d\une visite';


CREATE TABLE cor_visit_perturbation (
    id_base_visit integer NOT NULL,
    id_nomenclature_perturbation integer NOT NULL   
);
COMMENT ON TABLE pr_monitoring_flora_territory.cor_visit_perturbation IS 'Enregistrer les perturbations constatées lors d\une visite';


ALTER TABLE ONLY t_infos_site 
    ADD CONSTRAINT pk_id_t_infos_site PRIMARY KEY (id_infos_site);

ALTER TABLE ONLY cor_visit_grid
    ADD CONSTRAINT pk_cor_visit_grid PRIMARY KEY (id_area, id_base_visit);

ALTER TABLE ONLY cor_visit_perturbation 
    ADD CONSTRAINT pk_cor_visit_perturbation PRIMARY KEY (id_base_visit, id_nomenclature_perturbation);



---------------
--FOREIGN KEY--
---------------

ALTER TABLE ONLY t_infos_site 
    ADD CONSTRAINT fk_t_infos_site_id_base_site FOREIGN KEY (id_base_site) REFERENCES gn_monitoring.t_base_sites (id_base_site) ON UPDATE CASCADE ON DELETE CASCADE; 

ALTER TABLE ONLY t_infos_site
    ADD CONSTRAINT fk_t_infos_site_cd_nom FOREIGN KEY (cd_nom) REFERENCES taxonomie.taxref (cd_nom) ON UPDATE CASCADE;


ALTER TABLE ONLY cor_visit_grid
    ADD CONSTRAINT fk_cor_visit_grid_id_base_visit FOREIGN KEY (id_base_visit) REFERENCES gn_monitoring.t_base_visits (id_base_visit) ON UPDATE CASCADE ON DELETE CASCADE;

ALTER TABLE ONLY cor_visit_grid
    ADD CONSTRAINT fk_cor_visit_grid_id_area FOREIGN KEY (id_area) REFERENCES ref_geo.l_areas (id_area);


ALTER TABLE ONLY cor_visit_perturbation 
    ADD CONSTRAINT fk_cor_visit_perturbation_id_base_visit FOREIGN KEY (id_base_visit) REFERENCES gn_monitoring.t_base_visits (id_base_visit) ON UPDATE CASCADE;

ALTER TABLE ONLY cor_visit_perturbation 
    ADD CONSTRAINT fk_cor_visit_perturbation_id_nomenclature_perturbation FOREIGN KEY (id_nomenclature_perturbation) REFERENCES ref_nomenclatures.t_nomenclatures (id_nomenclature) ON UPDATE CASCADE;


--Créer la vue pour exporter les visites

   CREATE OR REPLACE VIEW pr_monitoring_flora_territory.export_visits AS WITH
    observers AS(
SELECT 
    v.id_base_visit,
    string_agg(roles.nom_role::text || ' ' ||  roles.prenom_role::text, ',') AS observateurs,
    roles.organisme AS organisme
FROM gn_monitoring.t_base_visits v
JOIN gn_monitoring.cor_visit_observer observer ON observer.id_base_visit = v.id_base_visit
JOIN utilisateurs.t_roles roles ON roles.id_role = observer.id_role
GROUP BY v.id_base_visit, roles.organisme
),
perturbations AS(
SELECT 
    v.id_base_visit,
    string_agg(n.label_default, ',') AS label_perturbation
FROM gn_monitoring.t_base_visits v
JOIN pr_monitoring_flora_territory.cor_visit_perturbation p ON v.id_base_visit = p.id_base_visit
JOIN ref_nomenclatures.t_nomenclatures n ON p.id_nomenclature_perturbation = n.id_nomenclature
GROUP BY v.id_base_visit
),
area AS(
SELECT bs.id_base_site,
       a.id_area,
       a.area_name
FROM ref_geo.l_areas a
JOIN gn_monitoring.t_base_sites bs ON ST_intersects(ST_TRANSFORM(a.geom, MY_SRID_WORLD), bs.geom)
WHERE a.id_type=ref_geo.get_id_area_type('COM')
)
-- toutes les mailles d'un site et leur visites
SELECT sites.id_base_site, cor.id_area, visits.id_base_visit, grid.presence, visits.id_digitiser, visits.visit_date_min, visits.comments, visits.uuid_base_visit, ar.geom,
    per.label_perturbation,
    obs.observateurs,
    obs.organisme,
    sites.base_site_name,
    taxon.nom_valide,
    taxon.cd_nom,
    area.area_name,
    ar.id_type
FROM gn_monitoring.t_base_sites sites
JOIN gn_monitoring.cor_site_area cor ON cor.id_base_site = sites.id_base_site
JOIN gn_monitoring.t_base_visits visits ON sites.id_base_site = visits.id_base_site
LEFT JOIN pr_monitoring_flora_territory.cor_visit_grid grid ON grid.id_area = cor.id_area AND grid.id_base_visit = visits.id_base_visit
JOIN observers obs ON obs.id_base_visit = visits.id_base_visit
LEFT JOIN perturbations per ON per.id_base_visit = visits.id_base_visit
JOIN area ON area.id_base_site = sites.id_base_site
JOIN pr_monitoring_flora_territory.t_infos_site info ON info.id_base_site = sites.id_base_site
JOIN taxonomie.taxref taxon ON taxon.cd_nom = info.cd_nom
JOIN ref_geo.l_areas ar ON ar.id_area = cor.id_area
WHERE ar.id_type=ref_geo.get_id_area_type('M25m')
ORDER BY visits.id_base_visit;

------------
--TRIGGERS--
------------
-- Idée: 
-- + Un trigger pour vérifier si id_nomenclature_perturbation dans la table cor_visit_perturbation 
--   correspond bien à celui stocké dans t_nomenclatures. 





--------------
-- DATA -----
--------------

-- Créer la liste des taxons suivis dans le protocoles SFT
INSERT INTO taxonomie.bib_listes (id_liste, nom_liste, desc_liste, regne, group2_inpn) 
VALUES (30, 'Suivi Flore Territoire', 'Taxons suivis dans le protocole Suivi Flore Territoire', 'Plantae', 'Angiospermes');

-- Insérer les taxons suivis dans le protocole SFT dans bib_noms et les ajouter dans la liste SFT
INSERT INTO taxonomie.bib_noms (cd_nom, cd_ref, nom_francais) VALUES (97133, 97133, 'Reine des Alpes, Chardon bleu'); -- Eryngium Alpinum
INSERT INTO taxonomie.cor_nom_liste (id_nom, id_liste) VALUES ((SELECT max(id_nom) FROM taxonomie.bib_noms), 30);
INSERT INTO taxonomie.bib_noms (cd_nom, cd_ref, nom_francais) VALUES (115458, 115458, 'Potentille du Dauphiné'); -- Potentille du Dauphine
INSERT INTO taxonomie.cor_nom_liste (id_nom, id_liste) VALUES ((SELECT max(id_nom) FROM taxonomie.bib_noms), 30);
INSERT INTO taxonomie.bib_noms (cd_nom, cd_ref, nom_francais) VALUES (127469, 127469, 'Trèfle des rochers'); -- Trifolium saxatile
INSERT INTO taxonomie.cor_nom_liste (id_nom, id_liste) VALUES ((SELECT max(id_nom) FROM taxonomie.bib_noms), 30);
INSERT INTO taxonomie.bib_noms (cd_nom, cd_ref, nom_francais) VALUES (84791, 84791, ''); -- Astragalus alopecurus
INSERT INTO taxonomie.cor_nom_liste (id_nom, id_liste) VALUES ((SELECT max(id_nom) FROM taxonomie.bib_noms), 30);
INSERT INTO taxonomie.bib_noms (cd_nom, cd_ref, nom_francais) VALUES (122959, 717782, ''); -- Serratula lycopifolia
INSERT INTO taxonomie.cor_nom_liste (id_nom, id_liste) VALUES ((SELECT max(id_nom) FROM taxonomie.bib_noms), 30);
