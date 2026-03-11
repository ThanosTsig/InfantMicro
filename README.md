# Infant Cortical Microstructure 👶🧠

This repository contains the MATLAB scripts used to generate the figures for the manuscript:

"Prenatal and early postnatal periods differentially shape the maturation of human cortical microstructure and myelin"

---

## Repository Structure

- **`code/infant_micro_figures.m`**
Main script used to generate all figures and supplementary figures in the manuscript.

The script is organised into multiple sections. The first three sections (`init_project`, `preparing_data` and `creating_gen_table`) must be executed first (in this order). After these have been run, the figure-specific sections can be executed independently.

Note that this script is tailored to analyses using the **Von Economo parcellation**, with the **Schaefer-200 parcellation** used for validation analyses. Adjustments will be required within the script if other parcellations are used.

Below is a description of each section.

### Initialisation and data preparation

- **`init_project`**
  Set up paths, define hard-code variables, and load essential data
  
- **`preparing_data`**
  Prepare the dataset for analysis by:
  - filtering the demographic file to include only participants with available MP files and vertex-wise parcellation label files
  - removing subsequent scans of longitudinal participants
  - excluding participants with postnatal age > 7 weeks
  - calculating the average microstructure profile of each parcel
  - concatenating parcel-wise profiles and cortical thickness into arrays (`MP_parc_economo`, `MP_parc_schaefer200`, and `thick_parc_economo`)
  - calculating central moments of the parcel-wise profiles
  - generating datasets excluding non-singleton participants (`moments_parc_no_twinsz and `MP_parc_no_twins`)

- **`creating_gen_table`**
  Generate summary tables containing subject ID, session ID, gestational age (GA), postmenstrual age (PMA), postnatal age (PNA), sex, parcel, thickness, centre of gravity, and variance values.

  Tables generated:
  - `gen_table_economo` (Von Economo, all participants)
  - `gen_table_no_twins` (Von Economo, only singletons)
  - `gen_table_schaefer200` (Schaefer-200, all participants)
 
  Additional tables containing parcel-averaged values across participants:
  - `gen_table_avg_economo`
  - `gen_table_avg_no_twins`
  - `gen_table_avg_schaefer200`
 
  Non-cortical and limbic parcels are excluded.

### Figure 1

- **`panel_A`**
  Plot participant age trajectorites from birth to scan, with lines coloured by sex.
  
- **`panel_B`**
  Scatter plot of PNA against GA, coloured by sex.
  Smoothed histograms of PNA and GA distributions.

### Figure 2

- **`panel_A`**
  Calculate and plot the average microstructure profile across all participants and parcels.
  
- **`panel_B`**
  Filter parcel-wise profiles using arbitrary thresholds of each central moment value.
  Divide the profiles into 100 bins based on the moment value.
  Compute the average microstructure profile within each bin and plot them in increasing order of the corresponding central moment.
  
- **`panel_C`**
  Compute and plot the average central moment values for each parcel across all participants.

### Figure 3

- **`panel_A`**
  Fit linear models (`moment ~ PMA + sex`) for each parcel.
  Plot t-values that survive FDR correction on the wk40 cortical surface.
  
- **`panel_B_profile_plots`**
  Repeat process of panel A and identify parcels with the two highest and two lowest t-values for each model.
  Isolate microstructure profiles from these parcels across participants.
  Apply a sliding window approach along the PMA range of the participants (window width = 1.5 weeks; 50% overlap).
  For each window, compute the average profile across participants for each of the two parcels with the highest and two lowest t-values of each model.
  Plot the resulting averaged profiles sorted by PMA.
  
- **`panel_B_scatter_plots`**
  Compute the correlation between T1w/T2w intensity and PMA at each cortical depth for the selected parcels (those used in the profile plots).
  Plot them as scatter plots of depth against correlation.
  **Note:** this section requires the profile plot section to be run first.

### Figure 4

- **`controlling_effects`**
  Fit linear models (`moment ~ GA + PNA + sex`) at each parcel.
  Plot FDR-significant t-values on the wk40 surface (one plot for each moment and each developmental variable, i.e. GA and PNA).
  
- **`no_control`**
  Fit linear models (`moment ~ GA + sex` and `moment ~ PNA + sex`) at each parcel.
  Plot FDR-significant t-values on the wk40 surface (one plot for each moment and each developmental variable).

### Figure 5

- **`panel_A`**
  Plot the first four geometric eigenmodes on the wk40 surface.
  **Note:** the first eigenmode is spatially uniform by construction

- **`panel_B`**
  Fit linear models (`moment ~ PMA + sex` and `moment ~ GA + PNA + sex`) without applying significance filtering.
  Spin the t-maps using precomputed permutation indices.
  Upsample the t-maps to vertex resolution (including the spun maps)
  Compute correlation between the t-maps and eigenmodes.
  Derive permutation p-values and 95% null intervals (2.5th-97.5th percentiles) from the spun maps.
  Visualise each correlation between the original t-maps and the three eigenmodes in scatter plots, including whiskers for null intervals and significance markers (* p < 0.05,  ** p < 0.01).
  **Note:** the surface plots below the scatter plots correspond to the t-maps generated in figures 3 and 4 without significance filtering. The code to generate these is not repeated in this section.
    
- **`panel_C`**
  Fit linear models using each vertex-wise t-map as the response variables and all seven unique combinations of eigenmodes as predictors.
  Extract adjusted R-squared values visualise them in a bar plot.

The code for generating the supplementary figures is described below.

---

- **`code/moment_age_model.m`**
  Function used for parcel-wise linear modeling of central moment metrics.

- **`code/calculate_moments.m`**
  Function by Casey Paquola (2022) used to calculate the central moments of the profiles

- The rest of the files in `code/` consist of selected **SurfStat** functions used for upsampling data and visualisating results on cortical surfaces.

  These functions are part of the **SurfStat MATLAB toolbox**, originally developed by Keith J. Worsley.

  The full toolbox can be obtained from this [GitHub repository](https://github.com/MICA-MNI/micaopen/tree/master/surfstat).

  Documentation and usage instructions for SurfStatcan be found [here](https://mica-mni.github.io/surfstat/).

---

- **`resources/`**
  
  - `spin_test_ind_wk40.mat`
    Precomputed spin permutation indices used for spatial permutation testing.
    
  - `week-40_pial_emode_2-4.txt`
    Precomputed geometric eigenmodes (2nd-4th) of the cortical surface of the "dhcpSym" 40-week population-average infant template [Williams et al., 2023](https://www.nature.com/articles/s41562-023-01542-8).
    These eigenmodes were obtained by applying the Laplace-Beltrami operator (LBO) to the surface mesh using code provided by [Pang et al. (2023)](https://www.nature.com/articles/s41586-023-06098-1).
    The file contains the vertex-wise values of the second to forth eigenmodes and can be used to investigate large-scale spatial patterns of cortical organisation or to relate cortical maps to geometric modes of the surface.
    They can be reused directly for analyses performed on the dhcpSym 40-week surface.
    
  - `colourmaps/`
    All colourmaps used for generating the figures in the manuscript.
    These perceptually uniform scientific colormaps are derived from [Crameri, F. (2020). Scientific colour maps](http://www.fabiocrameri.ch/colourmaps.php) and are publicly available.

  - `tpl-week-40/`
    Includes the week-40 pial surface, as well as the Von Economo's and Schaefer-200's week-40 template vertex-wise parcel indices.

  - `S1_Data.xlsx`
    This file contains precomputed values required to reproduce **Figure 5B**.
    - **Sheet 1** contains the correlations between the parcel-wise t-maps (for each age variable and central moment) and each of the three geometric eigenmodes (eigenmodes 2–4). The sheet also includes the associated permutation p-values and the 95% null distribution intervals (2.5th and 97.5th percentiles).
    - **Sheet 2** contains the parcel-wise t-values of the linear models used in the analysis, with each central moment as the response variable and each age variable as the predictor.  
  A value of `-100` is assigned to non-cortical and limbic parcels. No significance threshold was applied to these t-values. We've also added the parcel-wise average values of each central moment across all individuals, which can be used to generate Figure 2B.
      **Note:** If you wish to recompute the correlations between the t-maps and eigenmodes using the values provided in Sheet 2 (instead of generating them from scratch using the analysis scripts), replace the `-100` values with `NaN` before upsampling them to vertex-level using the `code/BoSurfStatMakeParcelData.m` function and performing the correlation analyses with the eigenmodes (`resources/week-40_pial_emode_2-4.txt`).

Individual-level data are **not included** in this repository. The data must be obtained and prepared as described in the **Data Availability** section below. After preparation, the data should be placed in a folder named `data/` within the root directory of the repository.

---

## Data Availability

The analyses were performed using data from the [developing Human Connectome Project (dHCP)](https://www.developingconnectome.org/) ([Hughes et al., 2017](https://onlinelibrary.wiley.com/doi/10.1002/mrm.26462)).

Access to these data is subject to the dHCP data use agreement.

To reproduce the figures in this repository, users must complete the following:

1. Obtain authorised access to the dataset.
2. Run the [CortPro pipeline](https://github.com/caseypaquola/CortPro) using the native T1w/T2w images as input to generate the microstructure profiles.
3. Align the parcellation schemes used in this study (Von Economo and Schaefer-200) to the native cortical surfaces via the [dhcpSym40 40-week infant template surface](https://www.nature.com/articles/s41562-023-01542-8). Use template-to-native registration spheres that were released with dHCP and [multimodal surface matching](https://doi.org/10.1016/j.neuroimage.2017.10.037) optimised for alignment of sulcal depth.
4. Place the output of CortPro (microstructure profile `.csv` files) in `InfantMicro/data/native_MPS/`.
5. Place the native parcellation label files (`.label.gii` files) in `InfantMicro/data/native_economo_ind` and 'InfantMicro/data/native_schaefer200_ind/` respectively.
7. Parcellate the cortical thickness values using the Von Economo parcellation and place the `.csv` files in the `InfantMicro/data/native_thick_economo`.

---

## Software Requirements

- MATLAB (tested on R2023a)
- Statistics and Machine Learning Toolbox
- [GIfTI toolbox](https://github.com/gllmflndn/gifti)

Users must ensure that these toolboxes are installed and added to the MATLAB path.

---

- **`code/infant_micro_figures.m`**, Supplementary figures

### Supplementary figures 1-3

- Fit linear models (`moment ~ PMA + sex` and `moment ~ GA + PNA + sex`) for each parcel using the full dataset and the dataset excluding non-singleton participants.

- Plot the resulting t-values on the wk40 cortical surface without applying significance filtering.

- Spin the t-maps of the full dataset using precomputed permutation indices.

- Compute correlation between the t-maps derived from the full dataset and those derived from the dataset excluding non-singleton participants.

- Derive permutation p-values from the correlations obtained using the spun maps.

### Supplementary figures 4-6

- Fit linear models (`moment ~ PMA + sex` and `moment ~ GA + PNA + sex`) for each parcel using the full dataset and the dataset excluding extremely preterm (EPT) infants (GA < 28 weeks; supp. figure 4), very preterm (VPT) infants (GA < 32 weeks; supp. figure 5) and preterm (PT) infants (GA < 37 weeks; supp. figure 6).

- Plot the resulting t-values on the wk40 cortical surface without applying significance filtering.

- Spin the t-maps of the full dataset using precomputed permutation indices.

- Compute correlation between the t-maps derived from the full dataset and those derived from the dataset excluding EPT, VPT and PT infants.

- Derive permutation p-values from the correlations obtained using the spun maps.

### Supplementary figures 7-9

- Fit linear models (`moment ~ PMA + sex` and `moment ~ GA + PNA + sex`) for each parcel using the data parcellated using the Von Economo atlas and data parcellated using the Schaefer-200 atlas.

- Plot the resulting t-values on the wk40 cortical surface without applying significance filtering.
  **Note:** To achieve the same masking of non-cortical and limbic parcels, the Von Economo results were upsampled to vertex-level and the vertex-indices of the non-cortical and limbic parcels were used to masked the data upsampled from the Schaefer-200 parcellation to vertex-level.

- Spin the t-maps of the Von Economo-parcellated data using precomputed permutation indices.

- Compute correlation between the t-maps Von Economo- and Schaefer-200-parcellated data, upon upsampling them to vertex-level.

- Derive permutation p-values from the correlations obtained using the spun maps.

### Supplementary figure 10

- Compute the average intensity per depth at each Von Economo parcel

- Plot the depth-wise intensity-maps on the wk40 cortical surface

### Supplementary figure 11

- Fit linear models (`moment ~ GA + sex` and `moment ~ PNA + sex`) for each parcel.

- Plot the resulting t-values on the wk40 cortical surface without applying significance filtering.

### Supplementary figures 12-14

- Fit linear models (`moment ~ PMA + sex` and `moment ~ GA + PNA + sex`) for each parcel with and without adding cortical thickness as a predictor in the models.

- Plot the resulting t-values on the wk40 cortical surface without applying significance filtering.

- Spin the t-maps derived from the models without cortical thickness as predictor using precomputed permutation indices.

- Compute correlation between the t-maps derived from the models without cortical thickness as predictor and those derived from the models with cortical thickness as predictor.

- Derive permutation p-values from the correlations obtained using the spun maps.
