# Infant Cortical Microstructure

This repository contains the MATLAB scripts used to generate the figures for the manuscript:

"Prenatal and early postnatal periods differentially shape the maturation of human cortical microstructure and myelin"

---

## Repository Structure

- `code/final_scripts.m`  
  Main script used to generate all manuscript's main and supplementary figures.

- `code/moment_age_model.m`  
  Function used for parcel-wise linear modeling of central moment metrics.

- `resources/`  
  Contains non-subject-specific files required for analysis (e.g., spin permutation indices).

Individual-level data are **not included** in this repository.

---

## Data Availability

This repository does not contain individual-level data.

The analyses were performed using data from the developing Human Connectome Project (dHCP).  
Access to these data is subject to the dHCP data use agreement.

To reproduce the figures, users must:

1. Obtain authorised access to the dataset.
2. Generate the required `.mat` files.
3. Place the `.mat` files in a local `data/` directory.

---

## Software Requirements

- MATLAB (tested on R2023a)
- Statistics and Machine Learning Toolbox
- SurfStat
- GIfTI toolbox

Users must ensure that these toolboxes are installed and added to the MATLAB path.

## Colourmaps

Figures use perceptually uniform scientific colormaps from:

Crameri, F. (2020). Scientific colour maps.

These colormaps are publicly available and can be obtained from:

[https://www.fabiocrameri.ch/colourmaps/](http://www.fabiocrameri.ch/colourmaps.php)

or via MATLAB-compatible distributions of the Scientific Colour Maps.

The scripts assume availability of colormaps "devon", "lajolla", "lapaz", "roma", "vik".
