# Infant Cortical Microstructure

This repository contains the MATLAB scripts used to generate the figures for the manuscript:

"Prenatal and early postnatal periods differentially shape the maturation of human cortical microstructure and myelin"

---

## Repository Structure

- `code/infant_micro_figures.m`  
  Main script used to generate all manuscript's main and supplementary figures. The script is separated in different sections. The first three sections (init_project, preparing_data and creating_gen_table) must be    run first (in order) before running the figure-specific sections. The figure-specific sections can be run independently. Please note that this script is tailored toward analysing the data using the Von Economo      parcellation, as well as the Schaefer-200 parcellation for validation. Adjustments will be needed within the script to analyse using different parcellations. Below a description of each section:
  - init_project: set up paths, hard-code variables, load essential data
  - preparing_data: filter the demographic file (only include participants with available MP files and vertex-wise parcellation label files), remove subsequent scans of longitudinal participants, exclude              participants with a postnatal age > 7, calculate the average profiles of each parcel and concatenate all parcel-wise profiles into a single array (MP_parc_economo and MP_parc_schaefer200), as well as the parcel-    wise thickness (thick_parc_economo), calculate the moments of the parcel-wise profiles and also prepare versions of the files upon excluding non-singleton participants using the Von Economo parcellation only        (moments_parc_no_twins and MP_parc_no_twins)
  - creating_gen_table: create 3 tables with the subject IDs, session IDs, gestational ages (GA), postmenstrual ages (PMA), postnatal ages (PNA), sex, parcel, thickness, centre of gravity and variance values for      each subject for Von Economo parcellation (with and without singleton participants) and for Schaefer-200 parcellation (all participants) --> gen_table_economo, gen_table_no_twins and gen_table_schaefer200. Also     create 3 tables with the average values of the above mentioned variables across all parcels (gen_table_avg_economo, gen_table_avg_no_twins and gen_table_avg_schaefer200). Filter out non-cortical and limbic parcels
  - figure_1:
    - panel_A: plot each participant's age as a line spanning from their time of birth to the day of the scan, separately-coloured for each sex
    - panel_B: plot a scatter plot of PNA agains GA, coloured by sex. Plot smoothed histograms of PNA and GA distributions
  - figure_2:
    - panel_A: calculate and plot the average profile across all participants and parcels
    - panel_B: sort parcellated profiles by each central moment (centre of gravity and variance) and plot them by increasing central moment in two separate plots
    - panel_C: calculate and plot the average moments in each parcel across all participants
  - figure_3:
    - panel_A: calculate the t-values of the linear models "moment ~ PMA + sex" at each parcel, filter the values that survive FDR correction and plot them on the wk40 surface
    - panel_B_profile_plots: repeat process of panel A, identify the parcels with the two highest/lowest t-values in each model, isolate the MP profiles within those parcels across individuals and plot the by             increasing PMA
    - panel_B_scatter_plots: calculate the correlation between T1w/T2w intensity and PMA at each depth within the sets of profiles for the parcels with the two highest/lowest t-values in each model (those used in         the profile plots) and plot them as scatter plots of depth against correlation. Please note that this section assumes that the section with the profile plots has been run prior to this.
  - figure_4:
    - controlling_effects: calculate the t-values of the linear models "moment ~ GA + PNA + sex" at each parcel, filter the values that survive FDR correction and plot them on the wk40 surface (one plot for each          moment and each developmental variable, i.e. GA and PNA)
    - no_control: calculate the t-values of the linear models "moment ~ GA + sex" and "moment ~ PNA + sex" at each parcel, filter the values that survive FDR correction and plot them on the wk40 surface (one plot         for each moment and each developmental variable, i.e. GA and PNA)
  - figure_5:
    - panel_A: plot the first 4 eigenmodes on the wk40 surface. Please note that the first eigenmode is spatially uniform by construction.
    - panel_B: calculate the t-values of the linear models "moment ~ PMA + sex" and "moment ~ GA + PNA + sex" at each parcel without filtering for significance, spin the maps using precomputed permutation indices,        upsample the t-maps for each developmental variable and moment to vertex-level (including the spun maps) and correlate them with each eigenmode. Calculate the two-tailed permutation p-value and the 95% null         distribution intervals (2.5th and 97.5th percentiles) from the correlation of the spun maps to the eigenmodes. Plot each correlation between the original t-maps and the three eigenmodes in a scatter plot and        add whiskers and asterisks (* = p<0.05 and ** = p<0.01) to deliniate the 95% null distribution intervals, as well as the permutation p-values. Note that the surface plots under the scatter plots are the same        ones generated in figures 3 and 4, but without applying significance filtering on the t-maps. The code to generate these is not repeated in this section.
    - panel_C: run linear models with each of the upsampled (vertex-wise) t-maps as response variables and all 7 unique combinations of eigenmodes as predictors, extract the adjusted R-squared values of each models      and plot them in a bar plot
  - the code for the generation of the supplementary figures is described below

- `code/moment_age_model.m`  
  Function used for parcel-wise linear modeling of central moment metrics.

- `resources/`  
  Contains non-subject-specific files required for analysis (e.g., spin permutation indices).
  input:  moment_metric      string for response variable in the model. Must be a column name of input_table ("cog" or "variance")
          age_metric         string for predictor variable or array of stringsof predictor variables. Must be a column name(s)of input_table ("PMA", "GA" and/or "PNA")
          input_table        table that contains subject-specific,parcel-wise values for each variable of interest
          uparc              parcel indices for which the models will be run. These must appear in the column "parcel" of input_table
          total_num_parcels  total number of parcels within the parcellation. This can be different from the number of parcels in uparc, if certain parcels are excluded from the analysis
          valid_parcels      array delineating the positions of the parcels of interest (uparc) within the actual number of parcels. These can sometime differ from the actual parcel index depending on the                                        parcellation scheme
          fdr_correction     logical value (0 or 1) stating whether FDR correction will be applied (1) or not (0). The parcel values which don't survive FDR correction are replaced with the value of 100
          thickness          logical value (0 or 1) stating whether thickness should be included as predictor in the models. Note that thickness values should appear under the table name "thick" in input_table
 
  output: parcel_data :      vector (length = total_num_parcels) with values:
                                   -100 : for parcels not within valid_parcels
                                   tStat-values: for parcels with significant effects
                                   100 : for parcels with no significant effects after FDR-correction (if chosen)
 
  Example:
    vec = moment_age_model('cen_of_grav','PMA', input_table, uparc, total_num_parcels, valid_parcels, 1, 0);

Individual-level data are **not included** in this repository. The data must be obtained and prepared as described below (see Data Availability)

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
