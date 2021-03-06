import { Component, OnInit, ViewChild, AfterViewInit } from '@angular/core';
import { Router, ActivatedRoute } from '@angular/router';

import { MapService } from '@geonature_common/map/map.service';
import { DataFormService } from '@geonature_common/form/data-form.service';
import { GeojsonComponent } from '@geonature_common/map/geojson/geojson.component';

import { StoreService } from '../services/store.service';
import { ModuleConfig } from '../module.config';
import { DataService } from '../services/data.service';

@Component({
  selector: 'pnx-detail-visit',
  templateUrl: 'detail-visit.component.html',
  styleUrls: ['./detail-visit.component.scss']
})
export class DetailVisitComponent implements OnInit, AfterViewInit {
  public zps;
  public nomTaxon;
  public date;
  public idVisit;
  public idSite;
  public tabPertur = [];
  public visitGrid = [];
  public tabObserver = [];

  public rows = [];

  public dataListVisit = [];
  public comments;
  // public queryString = new HttpParams();

  @ViewChild('geojson')
  geojson: GeojsonComponent;

  constructor(
    public mapService: MapService,
    private _api: DataService,
    public activatedRoute: ActivatedRoute,
    public storeService: StoreService,
    public router: Router,
    public dataFormService: DataFormService
  ) {}

  ngOnInit() {
    console.log('INIT');

    this.idVisit = this.activatedRoute.snapshot.params['idVisit'];
  }

  ngAfterViewInit() {
    this.mapService.map.doubleClickZoom.disable();

    this.activatedRoute.params.subscribe(params => {
      this.storeService.queryString = this.storeService.queryString.set(
        'id_base_visit',
        params.idVisit
      );
      this._api.getOneVisit(params.idVisit).subscribe(element => {
        this.comments = element.comments;
        this.visitGrid = element.cor_visit_grid;
        this.storeService.presence = 0;
        this.storeService.absence = 0;
        if (this.visitGrid !== undefined) {
          this.visitGrid.forEach(grid => {
            if (grid.presence == true) {
              this.storeService.presence += 1;
            } else {
              this.storeService.absence += 1;
            }
          });
        }

        let typePer;
        let tabVisitPerturb = element.cor_visit_perturbation;
        this.tabPertur = [];

        if (tabVisitPerturb !== undefined) {
          tabVisitPerturb.forEach(per => {
            if (per == tabVisitPerturb[tabVisitPerturb.length - 1]) {
              typePer = per.label_fr + '. ';
            } else {
              typePer = per.label_fr + ', ';
            }
            this.tabPertur.push(typePer);
          });
        }

        let fullNameObs;
        this.tabObserver = [];

        element.observers.forEach(obs => {
          if (obs == element.observers[element.observers.length - 1]) {
            fullNameObs = obs.nom_complet + '. ';
          } else {
            fullNameObs = obs.nom_complet + ', ';
          }
          this.tabObserver.push(fullNameObs);
        });

        this.date = element.visit_date_min;
        this.idSite = element.id_base_site;

        this._api
          .getMaille(this.idSite, { id_area_type: this.storeService.sftConfig.id_type_maille })
          .subscribe(data => {
            this.zps = data;
            this.storeService.total = data.features.length;
            this.storeService.getMailleNoVisit();
            this.geojson.currentGeoJson$.subscribe(currentLayer => {
              this.mapService.map.fitBounds(currentLayer.getBounds());
            });
          });

        this._api.getInfoSite(this.idSite).subscribe(info => {
          this.dataFormService.getTaxonInfo(info.cd_nom).subscribe(taxon => {
            this.nomTaxon = taxon.nom_valide;
          });
        });

        this._api.getVisits({ id_base_site: this.idSite }).subscribe(donnee => {
          donnee.forEach(visit => {
            let fullName;
            visit.observers.forEach(obs => {
              fullName = obs.nom_role + ' ' + obs.prenom_role;
            });
            visit.observers = fullName;
            let pres = 0;
            let abs = 0;

            if (visit.cor_visit_grid !== undefined) {
              visit.cor_visit_grid.forEach(maille => {
                if (maille.presence) {
                  pres += 1;
                } else {
                  abs += 1;
                }
              });
            }

            visit.state = pres + 'P / ' + abs + 'A ';
          });

          this.dataListVisit = donnee;

          this.rows = this.dataListVisit.filter(dataa => {
            return dataa.id_base_visit.toString() !== params.idVisit;
          });
        });
      });
    });
  }

  onEachFeature(feature, layer) {
    if (this.visitGrid !== undefined) {
      this.visitGrid.forEach(maille => {
        if (maille.id_area == feature.id) {
          if (maille.presence) {
            layer.setStyle(this.storeService.myStylePresent);
          } else {
            layer.setStyle(this.storeService.myStyleAbsent);
          }
        }
      });
    }
  }

  onEditHere() {
    this.activatedRoute.params.subscribe(params => {
      this.router.navigate([
        `${ModuleConfig.api_url}/editVisit`,
        this.idSite,
        'visit',
        params.idVisit
      ]);
    });
  }

  onEditOther(id_visit) {
    this.router.navigate([`${ModuleConfig.api_url}/editVisit`, this.idSite, 'visit', id_visit]);
  }

  onInfo(id_visit) {
    this.router.navigate([`${ModuleConfig.api_url}/infoVisit`, id_visit]);
  }
}
