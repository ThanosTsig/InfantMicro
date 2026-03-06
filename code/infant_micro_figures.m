for init_project = 1

    GH           = '/Users/ttsigaras/Documents/GitHub'; % GitHub directory
    homeDir      = [GH '/InfantMicro'];
    % directory of each participant's native microstructure profile csv
    MPs_dir      = [homeDir '/data/native_MPs'];
    % directory of vertex-wise Von Economo parcel indices
    labels_dir_economo   = [homeDir '/data/native_economo_ind'];
    % directory of vertex-wise Schaefer-200 parcel indices
    labels_dir_schaefer200 = [homeDir '/data/native_schaefer200_ind'];
    % directory of parcel-wise (Von Economo) cortical thickness
    thick_dir    = [homeDir '/data/native_thick_economo'];

    wk40_tpl_dir = [homeDir '/tpl-week-40']; % week-40 template directory

    % add paths for GitHub directories (gifti toolbox and scripts) 
    addpath(genpath([homeDir '/code']))
    addpath(genpath([GH '/gifti']))

    % load demographic data
    demographics = readtable([homeDir '/data/nnsi01.txt']); % load demographics file

    depths = 1:12; % number of depths per profile
    % defining valid parcels for each parcellation. Von Economo's
    % parcellation includes Corpus Callosum parcels (#2 and #47), which are
    % not assigned to any vertex, therefore although the official parcellation
    % includes 90 parcels, there are only 88 unique parcel indices when
    % extracting the unique indices from the label files. The below defined
    % parcels indices are actually the positions of the parcels within the
    % total number of parcels and not the actual indices
    total_num_parcels_economo = 88;
    total_num_parcels_schaefer200 = 201;
    excluded_indices_economo = [1, 15, 16, 17, 20, 21, 22, 23, 24, 25, 26, 45, ...
        59, 60, 61, 64, 65, 66, 67, 68, 69, 70]; % non-cortical and limbic  parcels
    valid_parcels_economo = setdiff(1:total_num_parcels_economo, ...
        excluded_indices_economo); % cortical and non-limbic parcel
    valid_parcels_schaefer200 = 2:201;

    % load week-40 pial surface
    wk40_lh_pial = gifti([wk40_tpl_dir '/week-40_hemi-left_space-dhcpSym_dens-32k_pial.surf.gii']);
    wk40_rh_pial = gifti([wk40_tpl_dir '/week-40_hemi-right_space-dhcpSym_dens-32k_pial.surf.gii']);
    wk40.tri = [wk40_lh_pial.faces; wk40_rh_pial.faces + size(wk40_lh_pial.vertices, 1)];
    wk40.coord = [wk40_lh_pial.vertices; wk40_rh_pial.vertices]';
    % load Von Economo's week-40 tpl vertex-wise parcel indices
    wk40_eco_lh_ind = gifti([wk40_tpl_dir '/week-40_hemi-left_desc-economo.label.gii']);
    wk40_eco_rh_ind = gifti([wk40_tpl_dir '/week-40_hemi-right_desc-economo.label.gii']);
    wk40_economo_ind = [wk40_eco_lh_ind.cdata + 1; wk40_eco_rh_ind.cdata + 46];
    % load Schaefer-200's week-40 tpl vertex-wise parcel indices
    wk40_sch200_lh_ind = gifti([wk40_tpl_dir '/week-40_hemi-left_desc-Schaefer2018_7Networks_200.32k.label.gii']);
    wk40_sch200_rh_ind = gifti([wk40_tpl_dir '/week-40_hemi-right_desc-Schaefer2018_7Networks_200.32k.label.gii']);
    wk40_schaefer200_ind = [wk40_sch200_lh_ind.cdata; wk40_sch200_rh_ind.cdata];

    % load colour maps
    load([homeDir '/resources/colourmaps/colorbrewer.mat'])
    scicol = [homeDir '/resources/colourmaps/ScientificColourMaps7'];
    scicol_names = ["devon", "lajolla", "lapaz", "roma", "vik"];
    for ii = 1:length(scicol_names)
        load(strcat(scicol, '/', scicol_names(ii), '.mat'));    
    end

    % load eigenmodes 2, 3 and 4
    eigenmodes = readmatrix([homeDir '/resources/week-40_pial_hemi-left_emode_2-4.txt']);
    % load previously used permutation indices
    load([homeDir '/resources/economo_spin_wk40.mat'], 'perm_id')

end

for preparing_data = 1

    variables = {'src_subject_id', 'scan_validation', 'nscan_ga_at_birth_weeks', ...
        'nscan_ga_at_scan_weeks', 'sex'};
    filt_demographics = table();
    
    for sub = 1:height(demographics)
        sub_id = demographics.src_subject_id{sub}; % subject ID
        ses_id = num2str(demographics.scan_validation(sub)); % session ID
    
        MP_file_dir = fullfile(MPs_dir, [sub_id '_ses-' ses_id '_desc-MP.csv']);
        left_label_file_dir_economo = fullfile(labels_dir_economo, [sub_id ...
            '_ses-' ses_id '_hemi-left_desc-economo.label.gii']);
        right_label_file_dir_economo = fullfile(labels_dir_economo, [sub_id ...
            '_ses-' ses_id '_hemi-right_desc-economo.label.gii']);
        
        % if all 3 files exist, add subject to the filtered table
        if isfile(MP_file_dir) && isfile(left_label_file_dir_economo) && ...
                isfile(right_label_file_dir_economo)
            filt_demographics = [filt_demographics; demographics(sub, variables)];
        else
            fprintf('Missing files for sub-%s_ses-%s.\n', sub_id, ses_id);
        end
    end

    % remove subsequent scans of longitudinal participants
    filt_demographics.scan_validation = double(filt_demographics.scan_validation);
    filt_demographics = sortrows(filt_demographics, ...
                             {'src_subject_id', 'scan_validation'});
    [~, first_idx] = unique(filt_demographics.src_subject_id, 'stable');
    filt_demographics = filt_demographics(first_idx, :);
    filt_demographics.postnatal_age = filt_demographics.nscan_ga_at_scan_weeks ...
        - filt_demographics.nscan_ga_at_birth_weeks; % calculate postnatal age at scan
    % excluding participants with PNA > 7
    filt_demographics(filt_demographics.postnatal_age > 7, :) = [];

    MP_parc_economo = nan(length(depths), total_num_parcels_economo, height(filt_demographics));
    MP_parc_schaefer200 = nan(length(depths), total_num_parcels_schaefer200, height(filt_demographics));
    thick_parc_economo = nan(total_num_parcels_economo, height(filt_demographics));
    for sub = 1:height(filt_demographics)
        sub_id = filt_demographics.src_subject_id{sub}; % subject ID
        ses_id = num2str(filt_demographics.scan_validation(sub)); % session ID
        
        MP_file_dir = fullfile(MPs_dir, [sub_id '_ses-' ses_id '_desc-MP.csv']);
        thick_file_dir = fullfile(thick_dir, [sub_id '_ses-' ses_id '_desc-thickness_parc-economo.csv']);
        left_label_file_dir_economo = fullfile(labels_dir_economo, ...
            [sub_id '_ses-' ses_id '_hemi-left_desc-economo.label.gii']);
        right_label_file_dir_economo = fullfile(labels_dir_economo, ...
            [sub_id '_ses-' ses_id '_hemi-right_desc-economo.label.gii']);
        left_label_file_dir_schaefer200 = fullfile(labels_dir_schaefer200, ...
            [sub_id '_ses-' ses_id '_hemi-left_desc-Schaefer2018_7Networks_200.32k.label.gii']);
        right_label_file_dir_schaefer200 = fullfile(labels_dir_schaefer200, ...
            [sub_id '_ses-' ses_id '_hemi-right_desc-Schaefer2018_7Networks_200.32k.label.gii']);

        MP = readmatrix(MP_file_dir); % read microstructure profiles
        sub_thick_parc = readmatrix(thick_file_dir); % read parcellated cortical thickness
        left_labels_economo = gifti(left_label_file_dir_economo);
        right_labels_economo = gifti(right_label_file_dir_economo);
        left_labels_schaefer200 = gifti(left_label_file_dir_schaefer200);
        right_labels_schaefer200 = gifti(right_label_file_dir_schaefer200);
        left_ind_economo = left_labels_economo.cdata;
        % add 45 to the right hemisphere parcel indices to differentiate them from the left hemisphere ones
        right_ind_economo = right_labels_economo.cdata + 45;
        left_ind_schaefer200 = left_labels_schaefer200.cdata;
        right_ind_schaefer200 = right_labels_schaefer200.cdata;
        economo_ind = cat(1, left_ind_economo, right_ind_economo); % vertex-wise Von Economo parcel indices
        schaefer200_ind = cat(1, left_ind_schaefer200, right_ind_schaefer200); % vertex-wise Schaefer-200 parcel indices

        num_of_parc_economo = unique(economo_ind);
        num_of_parc_schaefer200 = unique(schaefer200_ind);
        if length(num_of_parc_economo) == 88
            if length(num_of_parc_schaefer200) == 201
                sub_MP_parc_economo = zeros(size(MP, 1), length(num_of_parc_economo));
                sub_MP_parc_schaefer200 = zeros(size(MP, 1), length(num_of_parc_schaefer200));
                MP(isinf(MP)) = NaN;
    
                % calculate the average intensity per parcel at each depth
                for depth = 1:size(MP, 1)
                    sub_MP_parc_economo(depth,:) = grpstats(MP(depth,:) , economo_ind);
                    sub_MP_parc_schaefer200(depth,:) = grpstats(MP(depth,:) , schaefer200_ind);
                end
    
                MP_parc_economo(:,:,sub) = sub_MP_parc_economo;
                MP_parc_schaefer200(:,:,sub) = sub_MP_parc_schaefer200;
                thick_parc_economo(:,sub) = sub_thick_parc;
            else
                fprintf('Subject %s session %s has wrong number of Schaefer parcels.\n', sub_id, ses_id);
            end
        else
            fprintf('Subject %s session %s has wrong number of Von Economo parcels.\n', sub_id, ses_id);
        end
    end

    moments_parc_economo = NaN(5, total_num_parcels_economo, size(MP_parc_economo, 3));
    moments_parc_schaefer200 = NaN(5, total_num_parcels_schaefer200, size(MP_parc_schaefer200, 3));
    for sub = 1:height(filt_demographics)
        MP_economo = MP_parc_economo(:, :, sub);
        MP_schaefer200 = MP_parc_schaefer200(:, :, sub);
        MP_economo = round(MP_economo*100); % required for the calculate_moments() function to work
        MP_schaefer200= round(MP_schaefer200*100); % required for the calculate_moments() function to work
        % calculate the moments of this profile
        moments_economo = calculate_moments(MP_economo);
        moments_schaefer200 = calculate_moments(MP_schaefer200);
        moments_parc_economo(:, :, sub) = moments_economo;
        moments_parc_schaefer200(:, :, sub) = moments_schaefer200;
    end
    moments_parc_economo(1,:,:) = moments_parc_economo(1,:,:)/100;
    moments_parc_schaefer200(1,:,:) = moments_parc_schaefer200(1,:,:)/100;
    % exclude mean intensity, skewness and kurtosis from the moments
    moments_parc_economo([1 4 5], :, :) = [];
    moments_parc_schaefer200([1 4 5], :, :) = [];

    % exclude twins. Twins/Triples have the string "AN", "BN", "CN"
    % following the number in their subject ID, whereas singleton infants
    % have the string "XX"
    ids = string(filt_demographics.src_subject_id);
    expression = "CC(?<group>\d{5})(?<twin_id>[A-Z]{2})";
    tokens = regexp(ids, expression, 'names');
    tokens = vertcat(tokens{:});
    twin_id = string({tokens.twin_id}');
    is_twin = twin_id ~= "XX";
    filt_demographics_no_twins = filt_demographics(~is_twin,:);
    moments_parc_no_twins = moments_parc_economo(:,:,~is_twin);
    MP_parc_no_twins = MP_parc_economo(:,:,~is_twin);

end

for creating_gen_table = 1

    GA = filt_demographics.nscan_ga_at_birth_weeks; % gestational age [weeks]
    PNA = filt_demographics.postnatal_age; % postnatal age at scan [weeks]
    PMA = filt_demographics.nscan_ga_at_scan_weeks; % postmenstrual age at scan [weeks]
    sex = filt_demographics.sex; % sex
    sub_id = filt_demographics.src_subject_id; % subject ID
    ses_id = filt_demographics.scan_validation; % session ID

    GA_no_twins = filt_demographics_no_twins.nscan_ga_at_birth_weeks; % gestational age [weeks]
    PNA_no_twins = filt_demographics_no_twins.postnatal_age; % postnatal age at scan [weeks]
    PMA_no_twins = filt_demographics_no_twins.nscan_ga_at_scan_weeks; % postmenstrual age at scan [weeks]
    sex_no_twins = filt_demographics_no_twins.sex; % sex
    sub_id_no_twins = filt_demographics_no_twins.src_subject_id; % subject ID
    ses_id_no_twins = filt_demographics_no_twins.scan_validation; % session ID
    
    num_subjects = size(filt_demographics, 1);
    num_subjects_no_twins = size(filt_demographics_no_twins, 1);
    
    % repeating entries, in order to match the number of parcels per subject
    sub_id_rep_economo = repelem(sub_id, total_num_parcels_economo, 1);
    ses_id_rep_economo = repelem(ses_id, total_num_parcels_economo, 1);
    GA_rep_economo = repelem(GA, total_num_parcels_economo, 1);
    PNA_rep_economo = repelem(PNA, total_num_parcels_economo, 1);
    PMA_rep_economo = repelem(PMA, total_num_parcels_economo, 1);
    sex_rep_economo = repelem(sex, total_num_parcels_economo, 1);
    sub_id_rep_no_twins = repelem(sub_id_no_twins, total_num_parcels_economo, 1);
    ses_id_rep_no_twins = repelem(ses_id_no_twins, total_num_parcels_economo, 1);
    GA_rep_no_twins = repelem(GA_no_twins, total_num_parcels_economo, 1);
    PNA_rep_no_twins = repelem(PNA_no_twins, total_num_parcels_economo, 1);
    PMA_rep_no_twins = repelem(PMA_no_twins, total_num_parcels_economo, 1);
    sex_rep_no_twins = repelem(sex_no_twins, total_num_parcels_economo, 1);
    sub_id_rep_schaefer200 = repelem(sub_id, total_num_parcels_schaefer200, 1);
    ses_id_rep_schaefer200 = repelem(ses_id, total_num_parcels_schaefer200, 1);
    GA_rep_schaefer200 = repelem(GA, total_num_parcels_schaefer200, 1);
    PNA_rep_schaefer200 = repelem(PNA, total_num_parcels_schaefer200, 1);
    PMA_rep_schaefer200 = repelem(PMA, total_num_parcels_schaefer200, 1);
    sex_rep_schaefer200 = repelem(sex, total_num_parcels_schaefer200, 1);
    
    % multiplying the parcel indices with the number of subjects
    parcel_id_rep_economo = repmat(unique(wk40_economo_ind), num_subjects, 1);
    parcel_id_rep_no_twins = repmat(unique(wk40_economo_ind), num_subjects_no_twins, 1);
    parcel_id_rep_schaefer200 = repmat(unique(wk40_schaefer200_ind), num_subjects, 1);
    
    % reshaping the moments and cortical thickness to match the table's structure
    moments_rep_economo = reshape(moments_parc_economo, [2, total_num_parcels_economo * num_subjects])';
    thickness_rep = reshape(thick_parc_economo, [total_num_parcels_economo * num_subjects,1]);
    moments_rep_no_twins = reshape(moments_parc_no_twins, [2, total_num_parcels_economo * num_subjects_no_twins])';
    moments_rep_schaefer200 = reshape(moments_parc_schaefer200, [2, total_num_parcels_schaefer200 * num_subjects])';
    
    % creating the tables
    gen_table_economo = table(sub_id_rep_economo, ses_id_rep_economo, GA_rep_economo, ...
        PMA_rep_economo, PNA_rep_economo, sex_rep_economo, parcel_id_rep_economo, ...
        thickness_rep, moments_rep_economo(:,1), moments_rep_economo(:,2), ...
        'VariableNames', {'subject_id', 'session_id', 'GA', 'PMA', 'PNA', ...
        'sex', 'parcel', 'thick', 'cog', 'variance'});
    gen_table_no_twins = table(sub_id_rep_no_twins, ses_id_rep_no_twins, ...
        GA_rep_no_twins, PMA_rep_no_twins, PNA_rep_no_twins, sex_rep_no_twins, ...
        parcel_id_rep_no_twins, moments_rep_no_twins(:,1), moments_rep_no_twins(:,2), ...
        'VariableNames', {'subject_id', 'session_id', 'GA', 'PMA', 'PNA', ...
        'sex', 'parcel', 'cog', 'variance'});
    gen_table_schaefer200 = table(sub_id_rep_schaefer200, ses_id_rep_schaefer200, ...
        GA_rep_schaefer200, PMA_rep_schaefer200, PNA_rep_schaefer200, sex_rep_schaefer200, ...
        parcel_id_rep_schaefer200, moments_rep_schaefer200(:,1), moments_rep_schaefer200(:,2), ...
        'VariableNames', {'subject_id', 'session_id', 'GA', 'PMA', 'PNA', ...
        'sex', 'parcel', 'cog', 'variance'});

    % parcels to exclude from the Von Economo general table
    % (i.e. cortical wall, limbic and hippocampal lobes)
    exclude_parcels = [1, 16, 17, 18, 21, 22, 23, 24, 25, 26, 27, ...
                   46, 61, 62, 63, 66, 67, 68, 69, 70, 71, 72];

    % excluding subjects with a PNA lower than 7 weeks and also
    % parcels belonging to the cortical wall, hippocampal and limbic lobes
    gen_table_economo = gen_table_economo(gen_table_economo.PNA <= 7 & ...
                                ~ismember(gen_table_economo.parcel, exclude_parcels), :);
    gen_table_economo.sex = categorical(gen_table_economo.sex); % making sex a categorical variable
    gen_table_no_twins = gen_table_no_twins(gen_table_no_twins.PNA <= 7 & ...
                                ~ismember(gen_table_no_twins.parcel, exclude_parcels), :);
    gen_table_no_twins.sex = categorical(gen_table_no_twins.sex); % making sex a categorical variable
    gen_table_schaefer200.sex = categorical(gen_table_schaefer200.sex); % making sex a categorical variable

    % averaging central moments across subjects
    group_vars = {'subject_id', 'session_id', 'GA', 'PMA', 'PNA', 'sex'};
    avg_vars1 = {'thick', 'cog', 'variance'};
    avg_vars2 = {'cog', 'variance'};
    gen_table_avg_economo = groupsummary(gen_table_economo, group_vars, 'mean', avg_vars1);
    gen_table_avg_no_twins = groupsummary(gen_table_no_twins, group_vars, 'mean', avg_vars2);
    gen_table_avg_schaefer200 = groupsummary(gen_table_schaefer200, group_vars, 'mean', avg_vars2);
    for i = 1:numel(avg_vars1)
        old_name = ['mean_' avg_vars1{i}];
        newName = avg_vars1{i};
        gen_table_avg_economo.Properties.VariableNames{old_name} = newName;
    end
    for i = 1:numel(avg_vars2)
        old_name = ['mean_' avg_vars2{i}];
        newName = avg_vars2{i};
        gen_table_avg_no_twins.Properties.VariableNames{old_name} = newName;
        gen_table_avg_schaefer200.Properties.VariableNames{old_name} = newName;
    end
    gen_table_avg_economo.GroupCount = [];
    gen_table_avg_no_twins.GroupCount = [];
    gen_table_avg_schaefer200.GroupCount = [];

    uparc_economo = unique(gen_table_economo.parcel); % unique Von Economo parcel indices
    uparc_schaefer200 = unique(gen_table_schaefer200.parcel); % unique Schaefer-200 parcel indices
    uparc_schaefer200(1) = [];

end

for figure_1 = 1

    for panel_A = 1

        GA = gen_table_avg_economo.GA;
        PNA = gen_table_avg_economo.PNA;
        PMA = gen_table_avg_economo.PMA;
        sex = gen_table_avg_economo.sex;
    
        [~, sort_idx] = sortrows([PMA, PNA]); % sort first by PMA, then by PNA
        GA_sorted = GA(sort_idx);
        PMA_sorted = PMA(sort_idx);
        sex_sorted = sex(sort_idx);
        y_vals = 1:length(PMA_sorted);
    
        % plot each participant's age as a line spanning from their time of
        % birth to the day of the scan, separately-coloured for each sex
        figure('units','centimeters','outerposition',[0 0 56 20]); 
        hold on;
        for i = 1:length(GA_sorted)
            if sex_sorted(i) == 'M'
                plot([GA_sorted(i), PMA_sorted(i)], [y_vals(i), y_vals(i)], 'Color', lapaz(70,:), 'LineWidth', 0.5);
                scatter(GA_sorted(i), y_vals(i), 10, lapaz(70,:), 'filled', 'MarkerEdgeColor', lapaz(70,:));
                scatter(PMA_sorted(i), y_vals(i), 10, lapaz(70,:), 'filled', 'MarkerEdgeColor', lapaz(70,:));
            elseif sex_sorted(i) == 'F'
                plot([GA_sorted(i), PMA_sorted(i)], [y_vals(i), y_vals(i)], 'Color', lajolla(75,:), 'LineWidth', 0.5);
                scatter(GA_sorted(i), y_vals(i), 10, lajolla(75,:), 'filled', 'MarkerEdgeColor', lajolla(75,:));
                scatter(PMA_sorted(i), y_vals(i), 10, lajolla(75,:), 'filled', 'MarkerEdgeColor', lajolla(75,:));
            end
        end
        set(gca, 'YTick', []);
        set(gca, 'FontSize', 14);
        xlim([24 max(PMA_sorted)]);
        grid off;
        hold off;

    end

    for panel_B = 1

        % plot a scatter plot of PNA against GA, coloured by sex
        figure('units','centimeters','outerposition',[0 0 21 20]); 
        hold on;
        scatter(gen_table_avg_economo.GA(gen_table_avg_economo.sex == 'F'), ...
            gen_table_avg_economo.PNA(gen_table_avg_economo.sex == 'F'), ...
            50, 'filled', 'MarkerFaceColor', lajolla(75,:));
        scatter(gen_table_avg_economo.GA(gen_table_avg_economo.sex == 'M'), ...
            gen_table_avg_economo.PNA(gen_table_avg_economo.sex == 'M'), ...
            50, 'filled', 'MarkerFaceColor', devon(80,:));
        set(gca, 'FontSize', 14);
        ylim([0 max(gen_table_avg_economo.PNA)]);
        xlim([min(gen_table_avg_economo.GA) max(gen_table_avg_economo.GA)])
        grid off;
        hold off;

        % plot smoothed histograms of PNA and GA distributions
        variables = {'GA', 'PNA'};
        for i = 1:length(variables)
            var = variables{i};
            [f1, xi1] = ksdensity(gen_table_avg_economo.(var)(gen_table_avg_economo.sex == 'M'), 'Bandwidth', 0.4);
            [f2, xi2] = ksdensity(gen_table_avg_economo.(var)(gen_table_avg_economo.sex == 'F'), 'Bandwidth', 0.4);
            figure('units','centimeters','outerposition',[0 0 28 8]); 
            hold on;
            plot(xi1, f1, 'Color', devon(80,:), 'LineWidth', 2);
            fill(xi1, f1, devon(80,:), 'FaceAlpha', 0.3);
            plot(xi2, f2, 'Color', lajolla(75,:), 'LineWidth', 2);
            fill(xi2, f2, lajolla(75,:), 'FaceAlpha', 0.3);
            set(gca, 'XTick', [], 'YTick', []);
            xlim([min(gen_table_avg_economo.(var)) max(gen_table_avg_economo.(var))]);
            grid on;
            hold off;
        end

    end

end

for figure_2 = 1

    for panel_A = 1

        % calculate and plot the average profile across all participants
        % and parcels
        depth = 1:12;
        avg_profile = mean(MP_parc_economo(:, :, :), [2, 3]);
        figure('units','centimeters','outerposition',[0 0 10 22]); 
        plot(avg_profile, -depth, 'Color', 'k', 'LineWidth', 1.5);
        set(gca, 'YTick', []);
        set(gca, 'FontSize', 14);
        grid off;

    end

    for panel_B = 1

        cmap = flipud(roma);
        nsubs = size(MP_parc_economo, 3);
        nbins = 100;

        for m = 1:2
            profiles_reshaped = reshape(MP_parc_economo, [12, ...
                total_num_parcels_economo * nsubs]); % reshape profile array
            moments_reshaped = reshape(moments_parc_economo(m,:,:), ...
                [total_num_parcels_economo * nsubs, 1]); % flatten moment array
    
            if m == 1
                % mask profiles based on CoG value
                profiles_reshaped = profiles_reshaped(:, ...
                    moments_reshaped > 5.8); % arbitrary limit for CoG
                % assign each profile to a bin based on their CoG value
                mom_bins = discretize(moments_reshaped(moments_reshaped > 5.8), ...
                    nbins); % arbitrary limit for CoG
            else
                % mask profiles based on variance value
                profiles_reshaped = profiles_reshaped(:, ...
                    moments_reshaped < 3.4); % arbitrary limit for variance
                % assign each profile to a bin based on their variance value
                mom_bins = discretize(moments_reshaped(moments_reshaped < 3.4), ...
                    nbins); % arbitrary limit for variance
            end

            % plot the average profile within each bin
            figure('units','centimeters','outerposition',[0 0 10 22]); 
            hold on;
            for ii = 1:nbins
                plot(mean(profiles_reshaped(:,mom_bins==ii),2), -depths, ...
                    'Color', cmap(round(ii*height(cmap)/100), :), 'LineWidth', 1)
            end
            colormap(cmap);
            set(gca, 'FontSize', 14);
            set(gca, 'YTick', []);
            grid off;
            hold off;
    
        end

    end

    for panel_C = 1

        moment = ["Centre of gravity", "Variance"];
        % calculate average moments per parcel
        avg_moments = mean(moments_parc_economo, 3);
        % replace non-cortical and limbic parcel values with -100 for
        % visualisation purposes
        avg_moments(:, ~ismember(1:88, valid_parcels_economo)) = -100;
    
        for mom = 1:length(moment)
            min_val = min(avg_moments(mom, avg_moments(mom, :) > -100));
            min_val = min_val - min_val/100;
            vert_avg_moments = BoSurfStatMakeParcelData(avg_moments(mom,:), wk40, wk40_economo_ind);
            figure; SurfStatViewData(vert_avg_moments, wk40, strcat(moment(mom)));
            colormap([0.7 0.7 0.7; flipud(lajolla)]);
            SurfStatColLim([min_val, max(avg_moments(mom,:))]);
        end

    end

end

for figure_3 = 1

    for panel_A =1

        moments = ["Centre of gravity", "Variance"];
        
        for mom = 1:length(moments)
            if mom == 1
                cog_sign_parcel_data_PMA = moment_age_model("cog", "PMA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            else
                var_sign_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            end
        end
    
        % calculate maximum absolute value for limits
        min_val = min([min(cog_sign_parcel_data_PMA(cog_sign_parcel_data_PMA > -100)); ...
            min(var_sign_parcel_data_PMA(var_sign_parcel_data_PMA > -100))]);
        max_val = max([max(cog_sign_parcel_data_PMA(cog_sign_parcel_data_PMA < 100)); ...
            max(var_sign_parcel_data_PMA(var_sign_parcel_data_PMA < 100))]);
        abs_lim = max(abs(min_val), abs(max_val));
        abs_lim = abs_lim + abs_lim/100;
        
        % plot the significant effects of PMA on each moment
        for mom = 1:length(moments)
            if mom == 1
                sign_parc_data_PMA = cog_sign_parcel_data_PMA;
            else
                sign_parc_data_PMA = var_sign_parcel_data_PMA;
            end
            sign_vert_data_PMA = BoSurfStatMakeParcelData(sign_parc_data_PMA, wk40, wk40_economo_ind);
            figure; SurfStatViewData(sign_vert_data_PMA, wk40, strcat(moments(mom), ' sign. PMA'));
            colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
            % SurfStatColLim([-abs_lim, abs_lim]);
            % in the manuscript, we use the same colourscale limits as in
            % figure 4 for the purpose of comparison. If you want to use
            % limits based only on this data, use the line above
            SurfStatColLim([-30.8513, 30.8513]); % limits of figure 4
        end

    end

    for panel_B_profile_plots = 1

        moments = ["Centre of gravity", "Variance"];
        PMA = gen_table_avg_economo.PMA;
        min_PMA = min(PMA);
        max_PMA = max(PMA);
        % define a window size of 1.5 weeks and 50% overlap
        window_size = 1.5;
        step = 0.75;
        ages = min_PMA:step:max_PMA;
        
        for mom = 1:length(moments)
            if mom == 1
                sign_parcel_data_PMA = moment_age_model("cog", "PMA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            else
                sign_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            end
    
            % isolate the parcel-indices with the maximum/minimum significant effects
            max_change_parc = find(sign_parcel_data_PMA == ...
                max(sign_parcel_data_PMA(sign_parcel_data_PMA < 100)));
            min_change_parc = find(sign_parcel_data_PMA == ...
                min(sign_parcel_data_PMA(sign_parcel_data_PMA > -100)));
            % isolate the parcel-indices with the second maximum/minimum significnat effects
            sec_max_change_parc = find(sign_parcel_data_PMA == ...
                max(sign_parcel_data_PMA(sign_parcel_data_PMA ...
                < max(sign_parcel_data_PMA(sign_parcel_data_PMA<100)))));
            sec_min_change_parc = find(sign_parcel_data_PMA == ...
                min(sign_parcel_data_PMA(sign_parcel_data_PMA ...
                > min(sign_parcel_data_PMA(sign_parcel_data_PMA>-100)))));
    
            % isolate the MPs of the parcels with the first/second
            % maximum/minimum significant effects
            max_change_profs = MP_parc_economo(:,[max_change_parc ...
                sec_max_change_parc],:);
            min_change_profs = MP_parc_economo(:,[min_change_parc ...
                sec_min_change_parc],:);
            profiles_to_plot = [max_change_profs min_change_profs];
        
            % plot the profiles of the parcels with the first/second
            % maximum/minimum significant effects on CoG
            for i = 1:2
                profiles = profiles_to_plot(:,i*2-1:i*2,:);
                figure('units','centimeters','outerposition',[0 0 13 17]); 
                hold on;
                cmap = flipud(roma(round(linspace(1, 256, length(ages))), :));
                colormap(cmap);
                for j = 1:length(ages)-1
                    age_min = ages(j);
                    age_max = ages(j) + window_size;
                    idx = PMA >= age_min & PMA < age_max;
                    if sum(idx) == 0 % if no profiles within age-range, skip
                        continue;
                    end
                    avg_profile = mean(profiles(:, :, idx), [2, 3]);
                    plot(avg_profile, -depth, 'Color', cmap(j, :), 'LineWidth', 1.5);
                end
                colorbar;
                clim([min_PMA max_PMA]);
                set(gca, 'YTick', []);
                set(gca, 'FontSize', 14);
                if i==1
                    if mom == 1
                        xlim([0.6 1.5]) % arbitrary limits for max cog
                    else
                        xlim([0.7 1.9]) % arbitrary limits for max variance
                    end
                else
                    if mom == 1
                        xlim([0.6 1.8]) % arbitrary limits for min cog
                    else
                        xlim([0.8 1.7])  % arbitrary limits for min variance
                    end
                end
                grid off;
                hold off;
            end

            % store the profiles of the parcels with the maximum/minimum
            % effects separately for each moment to use in the scatter plots
            if mom == 1
                max_cog_change_profs = max_change_profs;
                min_cog_change_profs = min_change_profs;
            else
                max_var_change_profs = max_change_profs;
                min_var_change_profs = min_change_profs;
            end
        end

    end

    for panel_B_scatter_plots = 1

        for mom = 1:length(moments)
            for i = 1:2
                if mom == 1 && i == 1
                    profiles = max_cog_change_profs;
                elseif mom == 1 
                    profiles = min_cog_change_profs;
                elseif mom == 2 && i == 1
                    profiles = max_var_change_profs;
                else
                    profiles = min_var_change_profs;
                end

                % initialise array to store correlations at each depth
                depth_corrs = zeros(length(depths),1);
                % calculate correlation of intensities with PMA at each depth
                for depth = 1:length(depths)
                    depth_corrs(depth) = corr(squeeze(mean(profiles(depth,:,:),2)), gen_table_avg_economo.PMA);
                end
                
                % plot depth-wise correlations as a scatter plot
                figure('units','centimeters','outerposition',[0 0 13 17]);  hold on
                scatter(depth_corrs, depths, 90, 'filled', 'MarkerFaceColor', vik(80,:),...
                    'MarkerEdgeColor', 'k', 'LineWidth', 1.8);
                set(gca, 'YDir','reverse', 'YTick', [], 'YLim',[0 13], ...
                         'XLim', [0.18 0.75], 'TickLength',[0 0], 'FontSize', 14);
                grid off
            end
        end

    end

end

for figure_4 = 1

    for controlling_effects = 1
        moments = ["Centre of gravity", "Variance"];
        % run models which contain both GA and PNA as predictors (effects
        % controlling for the effects of the other)
        for mom = 1:length(moments)
            if mom == 1
                cog_sign_parcel_data = moment_age_model("cog", ["GA", "PNA"], ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            else
                var_sign_parcel_data = moment_age_model("variance", ["GA", "PNA"], ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            end
        end
    
        % calculate maximum absolute value for limits
        min_val = min([min(cog_sign_parcel_data(cog_sign_parcel_data > -100)); ...
            min(var_sign_parcel_data(var_sign_parcel_data > -100));]);
        max_val = max([max(cog_sign_parcel_data(cog_sign_parcel_data < 100)); ...
            max(var_sign_parcel_data(var_sign_parcel_data < 100))]);
        abs_lim = max([abs(min_val), abs(max_val)]);
        abs_lim = abs_lim + abs_lim/100;
    
        % plot the significant effects of GA and PNA on each moment
        for mom = 1:length(moments)
            if mom == 1
                sign_parcel_data_GA = cog_sign_parcel_data(:,1);
                sign_parcel_data_PNA = cog_sign_parcel_data(:,2);
            else
                sign_parcel_data_GA = var_sign_parcel_data(:,1);
                sign_parcel_data_PNA = var_sign_parcel_data(:,2);
            end
    
            sign_vert_data_PNA = BoSurfStatMakeParcelData(sign_parcel_data_PNA, wk40, wk40_economo_ind);
            figure; SurfStatViewData(sign_vert_data_PNA, wk40, strcat(moments(mom), ' sign. PNA'));
            colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
            SurfStatColLim([-abs_lim, abs_lim]);
            sign_vert_data_GA = BoSurfStatMakeParcelData(sign_parcel_data_GA, wk40, wk40_economo_ind);
            figure; SurfStatViewData(sign_vert_data_GA, wk40, strcat(moments(mom), ' sign. GA'));
            colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
            % SurfStatColLim([-abs_lim, abs_lim]);
            % in the manuscript, we use the same colourscale limits as the
            % figures of the independent models for the purpose of comparison.
            % If you want to use limits based only on this data, use the line above
            SurfStatColLim([-30.8513, 30.8513]); % limits of independent models
        end
    end

    for no_control = 1
        moments = ["Centre of gravity", "Variance"];
        % run individual models for GA and PNA as predictors (raw effects)
        for mom = 1:length(moments)
            if mom == 1
                cog_sign_parcel_data_GA = moment_age_model("cog", "GA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
                cog_sign_parcel_data_PNA = moment_age_model("cog", "PNA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            else
                var_sign_parcel_data_GA = moment_age_model("variance", "GA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
                var_sign_parcel_data_PNA = moment_age_model("variance", "PNA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            end
        end
    
        % calculate maximum absolute value for limits
        min_val = min([min(cog_sign_parcel_data_GA(cog_sign_parcel_data_GA > -100)); ...
            min(cog_sign_parcel_data_PNA(cog_sign_parcel_data_PNA > -100));
            min(var_sign_parcel_data_GA(var_sign_parcel_data_GA > -100)); ...
            min(var_sign_parcel_data_PNA(var_sign_parcel_data_PNA > -100))]);
        max_val = max([max(cog_sign_parcel_data_GA(cog_sign_parcel_data_GA < 100)); ...
            max(cog_sign_parcel_data_PNA(cog_sign_parcel_data_PNA < 100));
            max(var_sign_parcel_data_GA(var_sign_parcel_data_GA < 100)); ...
            max(var_sign_parcel_data_PNA(var_sign_parcel_data_PNA < 100))]);
        abs_lim = max([abs(min_val), abs(max_val)]);
        abs_lim = abs_lim + abs_lim/100;
    
        % plot the significant effects of GA and PNA on each moment
        for mom = 1:length(moments)
            if mom == 1
                sign_parcel_data_GA = cog_sign_parcel_data_GA;
                sign_parcel_data_PNA = cog_sign_parcel_data_PNA;
            else
                sign_parcel_data_GA = var_sign_parcel_data_GA;
                sign_parcel_data_PNA = var_sign_parcel_data_PNA;
            end
    
            sign_vert_data_PNA = BoSurfStatMakeParcelData(sign_parcel_data_PNA, wk40, wk40_economo_ind);
            figure; SurfStatViewData(sign_vert_data_PNA, wk40, strcat(moments(mom), ' sign. PNA'));
            colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
            SurfStatColLim([-abs_lim, abs_lim]);
            sign_vert_data_GA = BoSurfStatMakeParcelData(sign_parcel_data_GA, wk40, wk40_economo_ind);
            figure; SurfStatViewData(sign_vert_data_GA, wk40, strcat(moments(mom), ' sign. GA'));
            colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
            SurfStatColLim([-abs_lim, abs_lim]);
        end
    end

end

for figure_5 = 1

    for panel_A = 1
        
        % plotting first eigenmode
        eigenmode1 = eigenmodes(:,1);
        eigenmode1(eigenmode1~=0) = 1;
        figure; SurfStatViewData(eigenmode1, wk40);
        colormap([1 1 1; 0.1 0.01 0.56])

        % plotting vertex-wise eigenmodes 2-4
        for i = 1:size(eigenmodes, 2)
            figure; SurfStatViewData(eigenmodes(:,i), wk40);
            colormap(vik);
        end

    end

    for panel_B = 1

        % Note: the brain plots under the scatter plots are the same brain
        % plots generated in figures 3 and 4, but without applying significance
        % threshold on the t-maps and without a common colourscale. The code
        % to generate these is not repeated in this section
        n_perm = 10000; % number of permutations
        moments = ["Centre of gravity", "Variance"];
        
        % run linear models and concatenate t-values
        for mom = 1:length(moments)
            if mom == 1
                cog_parcel_data_PMA = moment_age_model("cog", "PMA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
                cog_parcel_data_GA_PNA = moment_age_model("cog", ["GA", "PNA"], ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            else
                var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
                var_parcel_data_GA_PNA = moment_age_model("variance", ["GA", "PNA"], ...
                    gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            end
        end
        t_maps = {cog_parcel_data_PMA, var_parcel_data_PMA, ...
            cog_parcel_data_GA_PNA(:,1), var_parcel_data_GA_PNA(:,1), ...
            cog_parcel_data_GA_PNA(:,2), var_parcel_data_GA_PNA(:,2)};
        for i = 1:numel(t_maps)
            t_maps{i}(t_maps{i} == -100) = NaN;
        end

        % spin the maps using the precomputed permutation indices
        spun_map = zeros(total_num_parcels_economo, n_perm, length(t_maps));
        for i = 1:length(t_maps)
            spun_map(:,:,i) = t_maps{i}(perm_id);
        end

        r_emp = zeros(length(t_maps), size(eigenmodes, 2));
        r_perm = zeros(n_perm, size(eigenmodes, 2), length(t_maps));
        spun_p = zeros(length(t_maps), size(eigenmodes, 2));
        null_prctiles = zeros(2, size(eigenmodes, 2), length(t_maps));
        for ii = 1:length(t_maps)
            spun_map = zeros(size(eigenmodes, 1), n_perm);
            % upsample parcel-wise effect maps to vertex-wise maps
            vert_t_map = BoSurfStatMakeParcelData(t_maps{ii}, wk40, wk40_economo_ind);
            for jj = 1:size(eigenmodes, 2)
                % correlate original effect map with eigenmode
                r_emp(ii, jj) = corr(vert_t_map', eigenmodes(:, jj), 'Rows', 'complete', 'Type', 'Pearson');
                % spin the parcel-wise effect map, upsample to vertex-wise
                % maps and correlate with eigenmode
                for kk = 1:n_perm
                    spun_map(:,kk) = BoSurfStatMakeParcelData(t_maps{ii}(perm_id(:,kk)), ...
                        wk40, wk40_economo_ind);
                    r_perm(kk, jj, ii) = corr(spun_map(:, kk), eigenmodes(:, jj), ...
                        'Rows', 'complete', 'Type', 'Pearson');
                end
                % calculate two-tailed permutation p-value
                spun_p(ii, jj) = sum(abs(r_perm(:, jj, ii)) >= abs(r_emp(ii, jj))) / n_perm;
                % 95% null distribution interval (2.5th and 97.5th percentiles)
                null_prctiles(:, jj, ii) = prctile(r_perm(:, jj, ii), [2.5, 97.5]);
            end
        end

        % plot correlations with each eigenmode for each age-metric separately
        start_x = 30;
        side_gap = 15;
        gap_within = 5;
        gap_between = 20;
        % positions to plot values
        positions = [start_x, start_x+gap_within, start_x+2*gap_within, ...
            start_x+2*gap_within+gap_between, start_x+3*gap_within+gap_between, ...
            start_x+4*gap_within+gap_between];
        
        groupped_by = 'moments'; % choose between 'moments' or 'eigenmodes'
        orientation = 'vertical'; % choose between 'horizontal' or 'vertical'
        
        for age_idx = 1:3 % {for age = PMA, GA, PNA}
            figure;
            hold on;
            
            if strcmp(groupped_by, 'moments')
                correlation = r_emp(age_idx*2-1:age_idx*2, :);
                correlation = reshape(correlation', 1, []);
                whiskers = null_prctiles(:, :, age_idx*2-1:age_idx*2);
                whiskers = reshape(whiskers, 2, []);
            elseif strcmp(groupped_by, 'eigenmodes')
                correlation = reshape(correlation, 1, []);
                whiskers = permute(whiskers, [1, 3, 2]);
                whiskers = reshape(whiskers, 2, 6);
            end
        
            col_scaled = round(1 + ((correlation + max(abs(correlation))) ./ ...
                (2 * max(abs(correlation)))) * 255);
        
            if strcmp(orientation, 'horizontal')
                xline(0, 'k--', 'LineWidth', 1);
                scatter(correlation, -positions, 120, vik(col_scaled,:), 'filled');
                for i = 1:6
                    plot([whiskers(1,i), whiskers(2,i)], [-positions(i), -positions(i)], ...
                        'Color', 'k', 'LineWidth', 1);
                end
                xlim([-(max(abs(correlation))+0.1), max(abs(correlation))+0.1]);
                ylim([-(max(positions)+side_gap), -(min(positions)-side_gap)]);
                set(gca, 'YTick', []);
            elseif strcmp(orientation, 'vertical')
                yline(0, 'k--', 'LineWidth', 1);
                scatter(positions, correlation, 120, vik(col_scaled,:), 'filled');
                for i = 1:6
                    plot([positions(i), positions(i)], [whiskers(1,i), whiskers(2,i)], ...
                        'Color', 'k', 'LineWidth', 1);
                end
                ylim([-(max(abs(correlation))+0.1), max(abs(correlation))+0.1]);
                xlim([min(positions)-side_gap, max(positions)+side_gap]);
                set(gca, 'XTick', []);
            end
        
            set(gca, 'FontSize', 14);
            grid off;
            hold off;
        end

    end

    for panel_C = 1

        % upsample parcel-wise effects maps to vertex-wise maps
        vertex_maps = cell(1, numel(t_maps));
        for i = 1:numel(t_maps)
            vertex_maps{i} = BoSurfStatMakeParcelData(t_maps{i}, ...
                wk40, wk40_economo_ind);
        end
        % concatenate vertex-wise effect maps and eigenmodes in a single table
        vertex_matrix = cat(2, vertex_maps{:});
        vertex_matrix = reshape(vertex_matrix, [], numel(vertex_maps));
        vertex_matrix = [vertex_matrix, eigenmodes(:,1), eigenmodes(:,2), eigenmodes(:,3)];
        tmaps_emodes_vert = array2table(vertex_matrix, 'VariableNames', ...
            {'cog_PMA','var_PMA', 'cog_GA','var_GA', ...
            'cog_PNA','var_PNA', 'EM1','EM2','EM3'});
    
        response_vars = ["cog_PMA","var_PMA","cog_GA","var_GA","cog_PNA","var_PNA"];
        
        regression_results = zeros(7,3,length(response_vars));
        % run linear models with each of the effect maps as response
        % variables and all 7 different combinations of eigenmodes as predictors
        for var = 1:length(response_vars)
            mdl_EM1 = fitlm(tmaps_emodes_vert, strcat(response_vars(var), ' ~ EM1'));
            regression_results(1,1,var) = mdl_EM1.Rsquared.Adjusted;
            mdl_EM2 = fitlm(tmaps_emodes_vert, strcat(response_vars(var), ' ~ EM2'));
            regression_results(2,1,var) = mdl_EM2.Rsquared.Adjusted;
            mdl_EM3 = fitlm(tmaps_emodes_vert, strcat(response_vars(var), ' ~ EM3'));
            regression_results(3,1,var) = mdl_EM3.Rsquared.Adjusted;
            mdl_EM1_2 = fitlm(tmaps_emodes_vert, strcat(response_vars(var), ' ~ EM1 + EM2'));
            regression_results(4,1,var) = mdl_EM1_2.Rsquared.Adjusted;
            mdl_EM1_3 = fitlm(tmaps_emodes_vert, strcat(response_vars(var), ' ~ EM1 + EM3'));
            regression_results(5,1,var) = mdl_EM1_3.Rsquared.Adjusted;
            mdl_EM2_3 = fitlm(tmaps_emodes_vert, strcat(response_vars(var), ' ~ EM2 + EM3'));
            regression_results(6,1,var) = mdl_EM2_3.Rsquared.Adjusted;
            mdl_EM1_2_3 = fitlm(tmaps_emodes_vert, strcat(response_vars(var), ' ~ EM1 + EM2 + EM3'));
            regression_results(7,1,var) = mdl_EM1_2_3.Rsquared.Adjusted;
        end
    
        r_sqrd_vals = squeeze(regression_results(:,1,:))';
    
        tmap_names = ["cog-PMA","var-PMA","cog-GA","var-GA","cog-PNA","var-PNA"];
        model_names = ["EM2","EM3","EM4","EM2+EM3","EM2+EM4","EM3+EM4","EM2+EM3+EM4"];

        % plot the adjusted R-square values of each model in a bar plot
        cols = [vik(145,:); vik(195,:)];
        gap_between = 1;
        block_width  = size(r_sqrd_vals,2) + gap_between;
        for age = 1:3
            figure('units','centimeters','outerposition',[0 0 20 12]); hold on;
            data_to_plot = r_sqrd_vals((age*2-1):age*2,:);
            for mom = 1:2
                x_pos = (mom-1)*block_width + (1:size(r_sqrd_vals,2));
                bar(x_pos,data_to_plot(mom,:), 0.8, 'FaceColor', cols(mom,:), ...
                    'EdgeColor', 'k', 'LineWidth', 1);
            end
            set(gca, 'FontSize', 14);
            ylim([0  max(r_sqrd_vals(:))*1.1]);
            box on;  grid off
        end 

    end

end

for supp_figure_1 = 1

    moments = ["Centre of gravity", "Variance"];
    % initialise table to store the correlations between the effect maps of
    % the original dataset and the dataset excluding twins
    r_emp = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
        
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data_PMA = moment_age_model("cog", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_no_twins = moment_age_model("cog", "PMA", ...
                gen_table_no_twins, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_no_twins = moment_age_model("variance", "PMA", ...
                gen_table_no_twins, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
        end
    end

    % calculate maximum absolute value for limits
    min_val = min([min(cog_parcel_data_PMA(cog_parcel_data_PMA > -100)); ...
        min(cog_parcel_data_PMA_no_twins(cog_parcel_data_PMA_no_twins > -100));
        min(var_parcel_data_PMA(var_parcel_data_PMA > -100)); ...
        min(var_parcel_data_PMA_no_twins(var_parcel_data_PMA_no_twins > -100))]);
    max_val = max([max(cog_parcel_data_PMA(cog_parcel_data_PMA < 100)); ...
        max(cog_parcel_data_PMA_no_twins(cog_parcel_data_PMA_no_twins < 100)); ...
        max(var_parcel_data_PMA(var_parcel_data_PMA < 100)); ...
        max(var_parcel_data_PMA_no_twins(var_parcel_data_PMA_no_twins < 100))]);
    abs_lim = max(abs(min_val), abs(max_val));
    abs_lim = abs_lim + abs_lim/100;
    
    % plot the significant effects of PMA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parc_data_PMA = cog_parcel_data_PMA;
            parc_data_PMA_no_twins = cog_parcel_data_PMA_no_twins;
        else
            parc_data_PMA = var_parcel_data_PMA;
            parc_data_PMA_no_twins = var_parcel_data_PMA_no_twins;
        end
    
        vert_data_PMA = BoSurfStatMakeParcelData(parc_data_PMA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PMA, wk40, strcat(moments(mom), ' PMA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PMA_no_twins = BoSurfStatMakeParcelData(parc_data_PMA_no_twins, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PMA_no_twins, wk40, strcat(moments(mom), ' PMA - no twins'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);

        % replace -100 values with NaNs for the correlation
        parc_data_PMA(parc_data_PMA==-100)=NaN;
        parc_data_PMA_no_twins(parc_data_PMA_no_twins==-100)=NaN;
        spun_map = parc_data_PMA(perm_id); % spin one of the maps of effects
        r_emp.Correlation(mom)=corr(parc_data_PMA, parc_data_PMA_no_twins, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the effects
        % run permutation test
        r_perm = zeros(n_perm,1);
        for kk=1:n_perm
            r_perm(kk) = corr(spun_map(:, kk), parc_data_PMA_no_twins, ...
                'Rows', 'complete', 'Type', 'Pearson');
        end
        r_emp.p_value(mom) = sum(abs(r_perm(:)) >= abs(r_emp.Correlation(mom))) / n_perm; % p-value after spin test
    end

end

for supp_figures_2_3 = 1

    moments = ["Centre of gravity", "Variance"];
    % initialise tables to store the correlations between the effect maps of
    % the original dataset and the dataset excluding twins
    r_emp_GA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    r_emp_PNA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);

    % run models which contain both GA and PNA as predictors (effects
    % controlling for the effects of the other)
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_no_twins = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_no_twins, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_no_twins = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_no_twins, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
        end
    end

    % calculate maximum absolute value for limits for each age-metric separately
    min_val_GA = min([min(cog_parcel_data(cog_parcel_data(:,1) > -100, 1)); ...
        min(cog_parcel_data_no_twins(cog_parcel_data_no_twins(:,1) > -100, 1)); ...
        min(var_parcel_data(var_parcel_data(:,1) > -100, 1)); ...
        min(var_parcel_data_no_twins(var_parcel_data_no_twins(:,1) > -100, 1))]);
    max_val_GA = max([max(cog_parcel_data(cog_parcel_data(:,1) < 100, 1)); ...
        max(cog_parcel_data_no_twins(cog_parcel_data_no_twins(:,1) < 100, 1)); ...
        max(var_parcel_data(var_parcel_data(:,1) < 100, 1)); ...
        max(var_parcel_data_no_twins(var_parcel_data_no_twins(:,1) < 100, 1))]);
    abs_lim_GA = max([abs(min_val_GA), abs(max_val_GA)]);
    abs_lim_GA = abs_lim_GA + abs_lim_GA/100;

    min_val_PNA = min([min(cog_parcel_data(cog_parcel_data(:,2) > -100, 2)); ...
        min(cog_parcel_data_no_twins(cog_parcel_data_no_twins(:,2) > -100, 2)); ...
        min(var_parcel_data(var_parcel_data(:,2) > -100, 2)); ...
        min(var_parcel_data_no_twins(var_parcel_data_no_twins(:,2) > -100, 2))]);
    max_val_PNA = max([max(cog_parcel_data(cog_parcel_data(:,2) < 100, 2)); ...
        max(cog_parcel_data_no_twins(cog_parcel_data_no_twins(:,2) < 100, 2)); ...
        max(var_parcel_data(var_parcel_data(:,2) < 100, 2)); ...
        max(var_parcel_data_no_twins(var_parcel_data_no_twins(:,2) < 100, 2))]);
    abs_lim_PNA = max([abs(min_val_PNA), abs(max_val_PNA)]);
    abs_lim_PNA = abs_lim_PNA + abs_lim_PNA/100;

    % plot the significant effects of GA and PNA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parcel_data_GA = cog_parcel_data(:,1);
            parcel_data_GA_no_twins = cog_parcel_data_no_twins(:,1);
            parcel_data_PNA = cog_parcel_data(:,2);
            parcel_data_PNA_no_twins = cog_parcel_data_no_twins(:,2);
        else
            parcel_data_GA = var_parcel_data(:,1);
            parcel_data_GA_no_twins = var_parcel_data_no_twins(:,1);
            parcel_data_PNA = var_parcel_data(:,2);
            parcel_data_PNA_no_twins = var_parcel_data_no_twins(:,2);
        end

        vert_data_PNA = BoSurfStatMakeParcelData(parcel_data_PNA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA, wk40, strcat(moments(mom), ' PNA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_PNA, abs_lim_PNA]);
        vert_data_PNA_no_twins = BoSurfStatMakeParcelData(parcel_data_PNA_no_twins, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA_no_twins, wk40, strcat(moments(mom), ' PNA - no twins'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_PNA, abs_lim_PNA]);
        vert_data_GA = BoSurfStatMakeParcelData(parcel_data_GA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA, wk40, strcat(moments(mom), ' GA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_GA, abs_lim_GA]);
        vert_data_GA_no_twins = BoSurfStatMakeParcelData(parcel_data_GA_no_twins, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA_no_twins, wk40, strcat(moments(mom), ' GA - no twins'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_GA, abs_lim_GA]);

        % replace -100 values with NaNs for the correlation
        parcel_data_GA(parcel_data_GA==-100)=NaN;
        parcel_data_GA_no_twins(parcel_data_GA_no_twins==-100)=NaN;
        parcel_data_PNA(parcel_data_PNA==-100)=NaN;
        parcel_data_PNA_no_twins(parcel_data_PNA_no_twins==-100)=NaN;
        spun_map_GA = parcel_data_GA(perm_id); % spin one of the GA maps of effects
        spun_map_PNA = parcel_data_PNA(perm_id); % spin one of the PNA maps of effects
        r_emp_GA.Correlation(mom)=corr(parcel_data_GA, parcel_data_GA_no_twins, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the GA effects
        r_emp_PNA.Correlation(mom)=corr(parcel_data_PNA, parcel_data_PNA_no_twins, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the PNA effects
        % run permutation test
        r_perm_GA = zeros(n_perm,1);
        r_perm_PNA = zeros(n_perm,1);
        for kk=1:n_perm
            r_perm_GA(kk) = corr(spun_map_GA(:, kk), parcel_data_GA_no_twins, ...
                'Rows', 'complete', 'Type', 'Pearson');
            r_perm_PNA(kk) = corr(spun_map_PNA(:, kk), parcel_data_PNA_no_twins, ...
                'Rows', 'complete', 'Type', 'Pearson');
        end
        r_emp_GA.p_value(mom) = sum(abs(r_perm_GA(:)) ...
            >= abs(r_emp_GA.Correlation(mom))) / n_perm; % p-value after spin test
        r_emp_PNA.p_value(mom) = sum(abs(r_perm_PNA(:)) ...
            >= abs(r_emp_PNA.Correlation(mom))) / n_perm; % p-value after spin test
    end

end

for supp_figure_4 = 1

    moments = ["Centre of gravity", "Variance"];
    % initialise table to store the correlations between the effect maps of the
    % original dataset and the dataset excluding extremely preterm (EPT) infants
    r_emp_PMA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    r_emp_GA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    r_emp_PNA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
        
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data_PMA = moment_age_model("cog", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_no_EPT = moment_age_model("cog", "PMA", ...
                gen_table_economo(gen_table_economo.GA >= 28, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA_no_EPT = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo(gen_table_economo.GA >= 28, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_no_EPT = moment_age_model("variance", "PMA", ...
                gen_table_economo(gen_table_economo.GA >= 28, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA_no_EPT = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo(gen_table_economo.GA >= 28, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
        end
    end

    % calculate maximum absolute value for limits
    min_val = min([min(cog_parcel_data_PMA(cog_parcel_data_PMA > -100)); ...
        min(cog_parcel_data_PMA_no_EPT(cog_parcel_data_PMA_no_EPT > -100)); ...
        min(cog_parcel_data_GA_PNA(cog_parcel_data_GA_PNA > -100)); ...
        min(cog_parcel_data_GA_PNA_no_EPT(cog_parcel_data_GA_PNA_no_EPT > -100)); ...
        min(var_parcel_data_PMA(var_parcel_data_PMA > -100)); ...
        min(var_parcel_data_PMA_no_EPT(var_parcel_data_PMA_no_EPT > -100)); ...
        min(var_parcel_data_GA_PNA(var_parcel_data_GA_PNA > -100)); ...
        min(var_parcel_data_GA_PNA_no_EPT(var_parcel_data_GA_PNA_no_EPT > -100))]);
    max_val = max([max(cog_parcel_data_PMA(cog_parcel_data_PMA < 100)); ...
        max(cog_parcel_data_PMA_no_EPT(cog_parcel_data_PMA_no_EPT < 100)); ...
        max(cog_parcel_data_GA_PNA(cog_parcel_data_GA_PNA < 100)); ...
        max(cog_parcel_data_GA_PNA_no_EPT(cog_parcel_data_GA_PNA_no_EPT < 100)); ...
        max(var_parcel_data_PMA(var_parcel_data_PMA < 100)); ...
        max(var_parcel_data_PMA_no_EPT(var_parcel_data_PMA_no_EPT < 100)); ...
        max(var_parcel_data_GA_PNA(var_parcel_data_GA_PNA < 100)); ...
        max(var_parcel_data_GA_PNA_no_EPT(var_parcel_data_GA_PNA_no_EPT < 100))]);
    abs_lim = max(abs(min_val), abs(max_val));
    abs_lim = abs_lim + abs_lim/100;
    
    % plot the significant effects of PMA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parcel_data_PMA = cog_parcel_data_PMA;
            parcel_data_PMA_no_EPT = cog_parcel_data_PMA_no_EPT;
            parcel_data_GA = cog_parcel_data_GA_PNA(:,1);
            parcel_data_GA_no_EPT = cog_parcel_data_GA_PNA_no_EPT(:,1);
            parcel_data_PNA = cog_parcel_data_GA_PNA(:,2);
            parcel_data_PNA_no_EPT = cog_parcel_data_GA_PNA_no_EPT(:,2);
        else
            parcel_data_PMA = var_parcel_data_PMA;
            parcel_data_PMA_no_EPT = var_parcel_data_PMA_no_EPT;
            parcel_data_GA = var_parcel_data_GA_PNA(:,1);
            parcel_data_GA_no_EPT = var_parcel_data_GA_PNA_no_EPT(:,1);
            parcel_data_PNA = var_parcel_data_GA_PNA(:,2);
            parcel_data_PNA_no_EPT = var_parcel_data_GA_PNA_no_EPT(:,2);
        end
    
        vert_data_PMA = BoSurfStatMakeParcelData(parcel_data_PMA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PMA, wk40, strcat(moments(mom), ' PMA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PMA_no_EPT = BoSurfStatMakeParcelData(parcel_data_PMA_no_EPT, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PMA_no_EPT, wk40, strcat(moments(mom), ' PMA - no EPT'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_GA = BoSurfStatMakeParcelData(parcel_data_GA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA, wk40, strcat(moments(mom), ' GA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_GA_no_EPT = BoSurfStatMakeParcelData(parcel_data_GA_no_EPT, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA_no_EPT, wk40, strcat(moments(mom), ' GA - no EPT'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PNA = BoSurfStatMakeParcelData(parcel_data_PNA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA, wk40, strcat(moments(mom), ' PNA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PNA_no_EPT = BoSurfStatMakeParcelData(parcel_data_PNA_no_EPT, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA_no_EPT, wk40, strcat(moments(mom), ' PNA - no EPT'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);

        % replace -100 values with NaNs for the correlation
        parcel_data_PMA(parcel_data_PMA==-100)=NaN;
        parcel_data_PMA_no_EPT(parcel_data_PMA_no_EPT==-100)=NaN;
        parcel_data_GA(parcel_data_GA==-100)=NaN;
        parcel_data_GA_no_EPT(parcel_data_GA_no_EPT==-100)=NaN;
        parcel_data_PNA(parcel_data_PNA==-100)=NaN;
        parcel_data_PNA_no_EPT(parcel_data_PNA_no_EPT==-100)=NaN;
        spun_map_PMA = parcel_data_PMA(perm_id); % spin one of the PMA maps of effects
        spun_map_GA = parcel_data_GA(perm_id); % spin one of the GA maps of effects
        spun_map_PNA = parcel_data_PNA(perm_id); % spin one of the PNA maps of effects
        r_emp_PMA.Correlation(mom)=corr(parcel_data_PMA, parcel_data_PMA_no_EPT, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the PMA effects
        r_emp_GA.Correlation(mom)=corr(parcel_data_GA, parcel_data_GA_no_EPT, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the GA effects
        r_emp_PNA.Correlation(mom)=corr(parcel_data_PNA, parcel_data_PNA_no_EPT, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the PNA effects
        % run permutation test
        r_perm_PMA = zeros(n_perm,1);
        r_perm_GA = zeros(n_perm,1);
        r_perm_PNA = zeros(n_perm,1);
        for kk=1:n_perm
            r_perm_PMA(kk) = corr(spun_map_PMA(:, kk), parcel_data_PMA_no_EPT, ...
                'Rows', 'complete', 'Type', 'Pearson');
            r_perm_GA(kk) = corr(spun_map_GA(:, kk), parcel_data_GA_no_EPT, ...
                'Rows', 'complete', 'Type', 'Pearson');
            r_perm_PNA(kk) = corr(spun_map_PNA(:, kk), parcel_data_PNA_no_EPT, ...
                'Rows', 'complete', 'Type', 'Pearson');
        end
        r_emp_PMA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_PMA.Correlation(mom))) / n_perm; % p-value after spin test
        r_emp_GA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_GA.Correlation(mom))) / n_perm; % p-value after spin test
        r_emp_PNA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_PNA.Correlation(mom))) / n_perm; % p-value after spin test
    end

end

for supp_figure_5 = 1

    moments = ["Centre of gravity", "Variance"];
    % initialise table to store the correlations between the effect maps of the
    % original dataset and the dataset excluding very preterm (VPT) infants
    r_emp_PMA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    r_emp_GA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    r_emp_PNA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
        
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data_PMA = moment_age_model("cog", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_no_VPT = moment_age_model("cog", "PMA", ...
                gen_table_economo(gen_table_economo.GA >= 32, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA_no_VPT = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo(gen_table_economo.GA >= 32, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_no_VPT = moment_age_model("variance", "PMA", ...
                gen_table_economo(gen_table_economo.GA >= 32, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA_no_VPT = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo(gen_table_economo.GA >= 32, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
        end
    end

    % calculate maximum absolute value for limits
    min_val = min([min(cog_parcel_data_PMA(cog_parcel_data_PMA > -100)); ...
        min(cog_parcel_data_PMA_no_VPT(cog_parcel_data_PMA_no_VPT > -100)); ...
        min(cog_parcel_data_GA_PNA(cog_parcel_data_GA_PNA > -100)); ...
        min(cog_parcel_data_GA_PNA_no_VPT(cog_parcel_data_GA_PNA_no_VPT > -100)); ...
        min(var_parcel_data_PMA(var_parcel_data_PMA > -100)); ...
        min(var_parcel_data_PMA_no_VPT(var_parcel_data_PMA_no_VPT > -100)); ...
        min(var_parcel_data_GA_PNA(var_parcel_data_GA_PNA > -100)); ...
        min(var_parcel_data_GA_PNA_no_VPT(var_parcel_data_GA_PNA_no_VPT > -100))]);
    max_val = max([max(cog_parcel_data_PMA(cog_parcel_data_PMA < 100)); ...
        max(cog_parcel_data_PMA_no_VPT(cog_parcel_data_PMA_no_VPT < 100)); ...
        max(cog_parcel_data_GA_PNA(cog_parcel_data_GA_PNA < 100)); ...
        max(cog_parcel_data_GA_PNA_no_VPT(cog_parcel_data_GA_PNA_no_VPT < 100)); ...
        max(var_parcel_data_PMA(var_parcel_data_PMA < 100)); ...
        max(var_parcel_data_PMA_no_VPT(var_parcel_data_PMA_no_VPT < 100)); ...
        max(var_parcel_data_GA_PNA(var_parcel_data_GA_PNA < 100)); ...
        max(var_parcel_data_GA_PNA_no_VPT(var_parcel_data_GA_PNA_no_VPT < 100))]);
    abs_lim = max(abs(min_val), abs(max_val));
    abs_lim = abs_lim + abs_lim/100;
    
    % plot the significant effects of PMA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parcel_data_PMA = cog_parcel_data_PMA;
            parcel_data_PMA_no_VPT = cog_parcel_data_PMA_no_VPT;
            parcel_data_GA = cog_parcel_data_GA_PNA(:,1);
            parcel_data_GA_no_VPT = cog_parcel_data_GA_PNA_no_VPT(:,1);
            parcel_data_PNA = cog_parcel_data_GA_PNA(:,2);
            parcel_data_PNA_no_VPT = cog_parcel_data_GA_PNA_no_VPT(:,2);
        else
            parcel_data_PMA = var_parcel_data_PMA;
            parcel_data_PMA_no_VPT = var_parcel_data_PMA_no_VPT;
            parcel_data_GA = var_parcel_data_GA_PNA(:,1);
            parcel_data_GA_no_VPT = var_parcel_data_GA_PNA_no_VPT(:,1);
            parcel_data_PNA = var_parcel_data_GA_PNA(:,2);
            parcel_data_PNA_no_VPT = var_parcel_data_GA_PNA_no_VPT(:,2);
        end
    
        vert_data_PMA = BoSurfStatMakeParcelData(parcel_data_PMA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PMA, wk40, strcat(moments(mom), ' PMA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PMA_no_VPT = BoSurfStatMakeParcelData(parcel_data_PMA_no_VPT, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PMA_no_VPT, wk40, strcat(moments(mom), ' PMA - no VPT'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_GA = BoSurfStatMakeParcelData(parcel_data_GA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA, wk40, strcat(moments(mom), ' GA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_GA_no_VPT = BoSurfStatMakeParcelData(parcel_data_GA_no_VPT, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA_no_VPT, wk40, strcat(moments(mom), ' GA - no VPT'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PNA = BoSurfStatMakeParcelData(parcel_data_PNA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA, wk40, strcat(moments(mom), ' PNA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PNA_no_VPT = BoSurfStatMakeParcelData(parcel_data_PNA_no_VPT, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA_no_VPT, wk40, strcat(moments(mom), ' PNA - no VPT'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);

        % replace -100 values with NaNs for the correlation
        parcel_data_PMA(parcel_data_PMA==-100)=NaN;
        parcel_data_PMA_no_VPT(parcel_data_PMA_no_VPT==-100)=NaN;
        parcel_data_GA(parcel_data_GA==-100)=NaN;
        parcel_data_GA_no_VPT(parcel_data_GA_no_VPT==-100)=NaN;
        parcel_data_PNA(parcel_data_PNA==-100)=NaN;
        parcel_data_PNA_no_VPT(parcel_data_PNA_no_VPT==-100)=NaN;
        spun_map_PMA = parcel_data_PMA(perm_id); % spin one of the PMA maps of effects
        spun_map_GA = parcel_data_GA(perm_id); % spin one of the GA maps of effects
        spun_map_PNA = parcel_data_PNA(perm_id); % spin one of the PNA maps of effects
        r_emp_PMA.Correlation(mom)=corr(parcel_data_PMA, parcel_data_PMA_no_VPT, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the PMA effects
        r_emp_GA.Correlation(mom)=corr(parcel_data_GA, parcel_data_GA_no_VPT, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the GA effects
        r_emp_PNA.Correlation(mom)=corr(parcel_data_PNA, parcel_data_PNA_no_VPT, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the PNA effects
        % run permutation test
        r_perm_PMA = zeros(n_perm,1);
        r_perm_GA = zeros(n_perm,1);
        r_perm_PNA = zeros(n_perm,1);
        for kk=1:n_perm
            r_perm_PMA(kk) = corr(spun_map_PMA(:, kk), parcel_data_PMA_no_VPT, ...
                'Rows', 'complete', 'Type', 'Pearson');
            r_perm_GA(kk) = corr(spun_map_GA(:, kk), parcel_data_GA_no_VPT, ...
                'Rows', 'complete', 'Type', 'Pearson');
            r_perm_PNA(kk) = corr(spun_map_PNA(:, kk), parcel_data_PNA_no_VPT, ...
                'Rows', 'complete', 'Type', 'Pearson');
        end
        r_emp_PMA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_PMA.Correlation(mom))) / n_perm; % p-value after spin test
        r_emp_GA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_GA.Correlation(mom))) / n_perm; % p-value after spin test
        r_emp_PNA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_PNA.Correlation(mom))) / n_perm; % p-value after spin test
    end

end

for supp_figure_6 = 1

    moments = ["Centre of gravity", "Variance"];
    % initialise table to store the correlations between the effect maps of the
    % original dataset and the dataset excluding preterm (PT) infants
    r_emp_PMA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    r_emp_GA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    r_emp_PNA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
        
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data_PMA = moment_age_model("cog", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_no_PT = moment_age_model("cog", "PMA", ...
                gen_table_economo(gen_table_economo.GA >= 37, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA_no_PT = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo(gen_table_economo.GA >= 37, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_no_PT = moment_age_model("variance", "PMA", ...
                gen_table_economo(gen_table_economo.GA >= 37, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA_no_PT = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo(gen_table_economo.GA >= 37, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
        end
    end

    % calculate maximum absolute value for limits
    min_val = min([min(cog_parcel_data_PMA(cog_parcel_data_PMA > -100)); ...
        min(cog_parcel_data_PMA_no_PT(cog_parcel_data_PMA_no_PT > -100)); ...
        min(cog_parcel_data_GA_PNA(cog_parcel_data_GA_PNA > -100)); ...
        min(cog_parcel_data_GA_PNA_no_PT(cog_parcel_data_GA_PNA_no_PT > -100)); ...
        min(var_parcel_data_PMA(var_parcel_data_PMA > -100)); ...
        min(var_parcel_data_PMA_no_PT(var_parcel_data_PMA_no_PT > -100)); ...
        min(var_parcel_data_GA_PNA(var_parcel_data_GA_PNA > -100)); ...
        min(var_parcel_data_GA_PNA_no_PT(var_parcel_data_GA_PNA_no_PT > -100))]);
    max_val = max([max(cog_parcel_data_PMA(cog_parcel_data_PMA < 100)); ...
        max(cog_parcel_data_PMA_no_PT(cog_parcel_data_PMA_no_PT < 100)); ...
        max(cog_parcel_data_GA_PNA(cog_parcel_data_GA_PNA < 100)); ...
        max(cog_parcel_data_GA_PNA_no_PT(cog_parcel_data_GA_PNA_no_PT < 100)); ...
        max(var_parcel_data_PMA(var_parcel_data_PMA < 100)); ...
        max(var_parcel_data_PMA_no_PT(var_parcel_data_PMA_no_PT < 100)); ...
        max(var_parcel_data_GA_PNA(var_parcel_data_GA_PNA < 100)); ...
        max(var_parcel_data_GA_PNA_no_PT(var_parcel_data_GA_PNA_no_PT < 100))]);
    abs_lim = max(abs(min_val), abs(max_val));
    abs_lim = abs_lim + abs_lim/100;
    
    % plot the significant effects of PMA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parcel_data_PMA = cog_parcel_data_PMA;
            parcel_data_PMA_no_PT = cog_parcel_data_PMA_no_PT;
            parcel_data_GA = cog_parcel_data_GA_PNA(:,1);
            parcel_data_GA_no_PT = cog_parcel_data_GA_PNA_no_PT(:,1);
            parcel_data_PNA = cog_parcel_data_GA_PNA(:,2);
            parcel_data_PNA_no_PT = cog_parcel_data_GA_PNA_no_PT(:,2);
        else
            parcel_data_PMA = var_parcel_data_PMA;
            parcel_data_PMA_no_PT = var_parcel_data_PMA_no_PT;
            parcel_data_GA = var_parcel_data_GA_PNA(:,1);
            parcel_data_GA_no_PT = var_parcel_data_GA_PNA_no_PT(:,1);
            parcel_data_PNA = var_parcel_data_GA_PNA(:,2);
            parcel_data_PNA_no_PT = var_parcel_data_GA_PNA_no_PT(:,2);
        end
    
        vert_data_PMA = BoSurfStatMakeParcelData(parcel_data_PMA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PMA, wk40, strcat(moments(mom), ' PMA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PMA_no_PT = BoSurfStatMakeParcelData(parcel_data_PMA_no_PT, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PMA_no_PT, wk40, strcat(moments(mom), ' PMA - no PT'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_GA = BoSurfStatMakeParcelData(parcel_data_GA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA, wk40, strcat(moments(mom), ' GA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_GA_no_PT = BoSurfStatMakeParcelData(parcel_data_GA_no_PT, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA_no_PT, wk40, strcat(moments(mom), ' GA - no PT'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PNA = BoSurfStatMakeParcelData(parcel_data_PNA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA, wk40, strcat(moments(mom), ' PNA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PNA_no_PT = BoSurfStatMakeParcelData(parcel_data_PNA_no_PT, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA_no_PT, wk40, strcat(moments(mom), ' PNA - no PT'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);

        % replace -100 values with NaNs for the correlation
        parcel_data_PMA(parcel_data_PMA==-100)=NaN;
        parcel_data_PMA_no_PT(parcel_data_PMA_no_PT==-100)=NaN;
        parcel_data_GA(parcel_data_GA==-100)=NaN;
        parcel_data_GA_no_PT(parcel_data_GA_no_PT==-100)=NaN;
        parcel_data_PNA(parcel_data_PNA==-100)=NaN;
        parcel_data_PNA_no_PT(parcel_data_PNA_no_PT==-100)=NaN;
        spun_map_PMA = parcel_data_PMA(perm_id); % spin one of the PMA maps of effects
        spun_map_GA = parcel_data_GA(perm_id); % spin one of the GA maps of effects
        spun_map_PNA = parcel_data_PNA(perm_id); % spin one of the PNA maps of effects
        r_emp_PMA.Correlation(mom)=corr(parcel_data_PMA, parcel_data_PMA_no_PT, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the PMA effects
        r_emp_GA.Correlation(mom)=corr(parcel_data_GA, parcel_data_GA_no_PT, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the GA effects
        r_emp_PNA.Correlation(mom)=corr(parcel_data_PNA, parcel_data_PNA_no_PT, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the PNA effects
        % run permutation test
        r_perm_PMA = zeros(n_perm,1);
        r_perm_GA = zeros(n_perm,1);
        r_perm_PNA = zeros(n_perm,1);
        for kk=1:n_perm
            r_perm_PMA(kk) = corr(spun_map_PMA(:, kk), parcel_data_PMA_no_PT, ...
                'Rows', 'complete', 'Type', 'Pearson');
            r_perm_GA(kk) = corr(spun_map_GA(:, kk), parcel_data_GA_no_PT, ...
                'Rows', 'complete', 'Type', 'Pearson');
            r_perm_PNA(kk) = corr(spun_map_PNA(:, kk), parcel_data_PNA_no_PT, ...
                'Rows', 'complete', 'Type', 'Pearson');
        end
        r_emp_PMA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_PMA.Correlation(mom))) / n_perm; % p-value after spin test
        r_emp_GA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_GA.Correlation(mom))) / n_perm; % p-value after spin test
        r_emp_PNA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_PNA.Correlation(mom))) / n_perm; % p-value after spin test
    end

end

for supp_figure_7 = 1

    moments = ["Centre of gravity", "Variance"];
    % initialise table to store the correlations between the effect maps on
    % Von Economo's parcels with the effect maps on Schaefer-200 parcels
    r_emp = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
        
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data_PMA = moment_age_model("cog", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_schaefer200 = moment_age_model("cog", "PMA", ...
                gen_table_schaefer200, uparc_schaefer200, ...
                total_num_parcels_schaefer200, valid_parcels_schaefer200, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_schaefer200 = moment_age_model("variance", "PMA", ...
                gen_table_schaefer200, uparc_schaefer200, ...
                total_num_parcels_schaefer200, valid_parcels_schaefer200, 0, 0);
        end
    end

    % calculate maximum absolute value for limits
    min_val = min([min(cog_parcel_data_PMA(cog_parcel_data_PMA > -100)); ...
        min(cog_parcel_data_PMA_schaefer200(cog_parcel_data_PMA_schaefer200 > -100));
        min(var_parcel_data_PMA(var_parcel_data_PMA > -100)); ...
        min(var_parcel_data_PMA_schaefer200(var_parcel_data_PMA_schaefer200 > -100))]);
    max_val = max([max(cog_parcel_data_PMA(cog_parcel_data_PMA < 100)); ...
        max(cog_parcel_data_PMA_schaefer200(cog_parcel_data_PMA_schaefer200 < 100)); ...
        max(var_parcel_data_PMA(var_parcel_data_PMA < 100)); ...
        max(var_parcel_data_PMA_schaefer200(var_parcel_data_PMA_schaefer200 < 100))]);
    abs_lim = max(abs(min_val), abs(max_val));
    abs_lim = abs_lim + abs_lim/100;
    
    % plot the significant effects of PMA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parc_data_PMA = cog_parcel_data_PMA;
            parc_data_PMA_schaefer200 = cog_parcel_data_PMA_schaefer200;
        else
            parc_data_PMA = var_parcel_data_PMA;
            parc_data_PMA_schaefer200 = var_parcel_data_PMA_schaefer200;
        end
    
        vert_data_PMA = BoSurfStatMakeParcelData(parc_data_PMA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PMA, wk40, strcat(moments(mom), ' PMA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PMA_schaefer200 = BoSurfStatMakeParcelData(parc_data_PMA_schaefer200, wk40, wk40_schaefer200_ind);
        vert_data_PMA_schaefer200(vert_data_PMA == -100) = -100;
        figure; SurfStatViewData(vert_data_PMA_schaefer200, wk40, strcat(moments(mom), ' PMA - Schaefer-200'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);

        % replace -100 values with NaNs for the correlation
        parc_data_PMA(parc_data_PMA==-100)=NaN;
        vert_data_PMA(vert_data_PMA==-100)=NaN;
        vert_data_PMA_schaefer200(vert_data_PMA_schaefer200==-100)=NaN;
        spun_map = parc_data_PMA(perm_id); % spin one of the maps of effects
        r_emp.Correlation(mom)=corr(vert_data_PMA', vert_data_PMA_schaefer200', ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the effects
        % run permutation test
        r_perm = zeros(n_perm,1);
        for kk=1:n_perm
            vert_spun_map = BoSurfStatMakeParcelData(spun_map(:, kk), wk40, wk40_economo_ind);
            r_perm(kk) = corr(vert_spun_map', vert_data_PMA_schaefer200', ...
                'Rows', 'complete', 'Type', 'Pearson');
        end
        r_emp.p_value(mom) = sum(abs(r_perm(:)) >= abs(r_emp.Correlation(mom))) / n_perm; % p-value after spin test
    end

end

for supp_figure_8_9 = 1

    moments = ["Centre of gravity", "Variance"];
    % initialise tables to store the correlations between the effect maps on
    % Von Economo's parcels with the effect maps on Schaefer-200 parcels
    r_emp_GA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    r_emp_PNA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
        
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_schaefer200 = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_schaefer200, uparc_schaefer200, ...
                total_num_parcels_schaefer200, valid_parcels_schaefer200, 0, 0);
        else
            var_parcel_data = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_schaefer200 = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_schaefer200, uparc_schaefer200, ...
                total_num_parcels_schaefer200, valid_parcels_schaefer200, 0, 0);
        end
    end

    % calculate maximum absolute value for limits
    min_val_GA = min([min(cog_parcel_data(cog_parcel_data(:,1) > -100, 1)); ...
        min(cog_parcel_data_schaefer200(cog_parcel_data_schaefer200(:,1) > -100, 1)); ...
        min(var_parcel_data(var_parcel_data(:,1) > -100, 1)); ...
        min(var_parcel_data_schaefer200(var_parcel_data_schaefer200(:,1) > -100, 1))]);
    max_val_GA = max([max(cog_parcel_data(cog_parcel_data(:,1) < 100, 1)); ...
        max(cog_parcel_data_schaefer200(cog_parcel_data_schaefer200(:,1) < 100, 1)); ...
        max(var_parcel_data(var_parcel_data(:,1) < 100, 1)); ...
        max(var_parcel_data_schaefer200(var_parcel_data_schaefer200(:,1) < 100, 1))]);
    abs_lim_GA = max([abs(min_val_GA), abs(max_val_GA)]);
    abs_lim_GA = abs_lim_GA + abs_lim_GA/100;

    min_val_PNA = min([min(cog_parcel_data(cog_parcel_data(:,2) > -100, 2)); ...
        min(cog_parcel_data_schaefer200(cog_parcel_data_schaefer200(:,2) > -100, 2)); ...
        min(var_parcel_data(var_parcel_data(:,2) > -100, 2)); ...
        min(var_parcel_data_schaefer200(var_parcel_data_schaefer200(:,2) > -100, 2))]);
    max_val_PNA = max([max(cog_parcel_data(cog_parcel_data(:,2) < 100, 2)); ...
        max(cog_parcel_data_schaefer200(cog_parcel_data_schaefer200(:,2) < 100, 2)); ...
        max(var_parcel_data(var_parcel_data(:,2) < 100, 2)); ...
        max(var_parcel_data_schaefer200(var_parcel_data_schaefer200(:,2) < 100, 2))]);
    abs_lim_PNA = max([abs(min_val_PNA), abs(max_val_PNA)]);
    abs_lim_PNA = abs_lim_PNA + abs_lim_PNA/100;
    
    % plot the significant effects of PMA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parcel_data_GA = cog_parcel_data(:,1);
            parcel_data_GA_schaefer200 = cog_parcel_data_schaefer200(:,1);
            parcel_data_PNA = cog_parcel_data(:,2);
            parcel_data_PNA_schaefer200 = cog_parcel_data_schaefer200(:,2);
        else
            parcel_data_GA = var_parcel_data(:,1);
            parcel_data_GA_schaefer200 = var_parcel_data_schaefer200(:,1);
            parcel_data_PNA = var_parcel_data(:,2);
            parcel_data_PNA_schaefer200 = var_parcel_data_schaefer200(:,2);
        end
    
        vert_data_GA = BoSurfStatMakeParcelData(parcel_data_GA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA, wk40, strcat(moments(mom), ' GA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_GA, abs_lim_GA]);
        vert_data_GA_schaefer200 = BoSurfStatMakeParcelData(parcel_data_GA_schaefer200, wk40, wk40_schaefer200_ind);
        vert_data_GA_schaefer200(vert_data_GA == -100) = -100;
        figure; SurfStatViewData(vert_data_GA_schaefer200, wk40, strcat(moments(mom), ' GA - Schaefer-200'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_GA, abs_lim_GA]);
        vert_data_PNA = BoSurfStatMakeParcelData(parcel_data_PNA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA, wk40, strcat(moments(mom), ' PNA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_PNA, abs_lim_PNA]);
        vert_data_PNA_schaefer200 = BoSurfStatMakeParcelData(parcel_data_PNA_schaefer200, wk40, wk40_schaefer200_ind);
        vert_data_PNA_schaefer200(vert_data_PNA == -100) = -100;
        figure; SurfStatViewData(vert_data_PNA_schaefer200, wk40, strcat(moments(mom), ' PNA - Schaefer-200'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_PNA, abs_lim_PNA]);

        % replace -100 values with NaNs for the correlation
        parcel_data_GA(parcel_data_GA==-100)=NaN;
        vert_data_GA(vert_data_GA==-100)=NaN;
        vert_data_GA_schaefer200(vert_data_GA_schaefer200==-100)=NaN;
        parcel_data_PNA(parcel_data_PNA==-100)=NaN;
        vert_data_PNA(vert_data_PNA==-100)=NaN;
        vert_data_PNA_schaefer200(vert_data_PNA_schaefer200==-100)=NaN;
        spun_map_GA = parcel_data_GA(perm_id); % spin one of the GA maps of effects
        spun_map_PNA = parcel_data_PNA(perm_id); % spin one of the PNA maps of effects
        r_emp_GA.Correlation(mom)=corr(vert_data_GA', vert_data_GA_schaefer200', ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the effects
        r_emp_PNA.Correlation(mom)=corr(vert_data_PNA', vert_data_PNA_schaefer200', ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the effects
        % run permutation test
        r_perm_GA = zeros(n_perm,1);
        r_perm_PNA = zeros(n_perm,1);
        for kk=1:n_perm
            vert_spun_map_GA = BoSurfStatMakeParcelData(spun_map_GA(:, kk), wk40, wk40_economo_ind);
            vert_spun_map_PNA = BoSurfStatMakeParcelData(spun_map_PNA(:, kk), wk40, wk40_economo_ind);
            r_perm_GA(kk) = corr(vert_spun_map_GA', vert_data_GA_schaefer200', ...
                'Rows', 'complete', 'Type', 'Pearson');
            r_perm_PNA(kk) = corr(vert_spun_map_PNA', vert_data_PNA_schaefer200', ...
                'Rows', 'complete', 'Type', 'Pearson');
        end
        r_emp_GA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_GA.Correlation(mom))) / n_perm; % p-value after spin test
        r_emp_PNA.p_value(mom) = sum(abs(r_perm(:)) ...
            >= abs(r_emp_PNA.Correlation(mom))) / n_perm; % p-value after spin test
    end

end

for supp_figure_10 = 1

    min_val = 0.7;
    max_val = 2.1;
    for depth = 1:height(MP_parc_economo)
        % average intensities per parcel for each depth
        avg_intensities = mean(MP_parc_economo(depth, :, :), 3);
        % mask non-cortical and limbic parcels
        avg_intensities(~ismember(1:88, valid_parcels_economo)) = -100;
        vert_avg_intensities = BoSurfStatMakeParcelData(avg_intensities, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_avg_intensities, wk40, strcat('Depth: ', string(depth)));
        colormap([0.7 0.7 0.7; flipud(lajolla)]);
        SurfStatColLim([min_val, max_val]);
    end

end

for supp_figure_11 = 1

    moments = ["Centre of gravity", "Variance"];
    % run models for GA and PNA as predictors separately
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data_GA = moment_age_model("cog", "GA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PNA = moment_age_model("cog", "PNA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_GA = moment_age_model("variance", "GA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PNA = moment_age_model("variance", "PNA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
        end
    end

    % calculate maximum absolute value for limits for each age-metric separately
    min_val = min([min(cog_parcel_data_GA(cog_parcel_data_GA > -100, 1)); ...
        min(cog_parcel_data_PNA(cog_parcel_data_PNA > -100, 1)); ...
        min(var_parcel_data_GA(var_parcel_data_GA > -100, 1)); ...
        min(var_parcel_data_PNA(var_parcel_data_PNA > -100, 1))]);
    max_val = max([max(cog_parcel_data_GA(cog_parcel_data_GA(:,1) < 100, 1)); ...
        max(cog_parcel_data_PNA(cog_parcel_data_PNA(:,1) < 100, 1)); ...
        max(var_parcel_data_GA(var_parcel_data_GA(:,1) < 100, 1)); ...
        max(var_parcel_data_PNA(var_parcel_data_PNA(:,1) < 100, 1))]);
    abs_lim = max([abs(min_val), abs(max_val)]);
    abs_lim = abs_lim + abs_lim/100;

    % plot the significant effects of GA and PNA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parcel_data_GA = cog_parcel_data_GA;
            parcel_data_PNA = cog_parcel_data_PNA;
        else
            parcel_data_GA = var_parcel_data_GA;
            parcel_data_PNA = var_parcel_data_PNA;
        end

        vert_data_GA = BoSurfStatMakeParcelData(parcel_data_GA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA, wk40, strcat(moments(mom), ' GA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_PNA = BoSurfStatMakeParcelData(parcel_data_PNA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA, wk40, strcat(moments(mom), ' PNA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
    end

end

for supp_figure_12 = 1

    moments = ["Centre of gravity", "Variance"];
    % initialise table to store the correlations between the effect maps
    % with and without correcting for cortical thickness
    r_emp = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
        
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data = moment_age_model("cog", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_thick_corr = moment_age_model("cog", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 1);
        else
            var_parcel_data = moment_age_model("variance", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_thick_corr = moment_age_model("variance", "PMA", ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 1);
        end
    end

    % calculate maximum absolute value for limits
    min_val = min([min(cog_parcel_data(cog_parcel_data > -100)); ...
        min(cog_parcel_data_thick_corr(cog_parcel_data_thick_corr > -100));
        min(var_parcel_data(var_parcel_data > -100)); ...
        min(var_parcel_data_thick_corr(var_parcel_data_thick_corr > -100))]);
    max_val = max([max(cog_parcel_data(cog_parcel_data < 100)); ...
        max(cog_parcel_data_thick_corr(cog_parcel_data_thick_corr < 100)); ...
        max(var_parcel_data(var_parcel_data < 100)); ...
        max(var_parcel_data_thick_corr(var_parcel_data_thick_corr < 100))]);
    abs_lim = max(abs(min_val), abs(max_val));
    abs_lim = abs_lim + abs_lim/100;
    
    % plot the significant effects of PMA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parcel_data = cog_parcel_data;
            parcel_data_thick_corr = cog_parcel_data_thick_corr;
        else
            parcel_data = var_parcel_data;
            parcel_data_thick_corr = var_parcel_data_thick_corr;
        end
    
        vert_data = BoSurfStatMakeParcelData(parcel_data, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data, wk40, strcat(moments(mom), ' PMA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);
        vert_data_thick_corr = BoSurfStatMakeParcelData(parcel_data_thick_corr, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_thick_corr, wk40, strcat(moments(mom), ' PMA - thickness correction'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim, abs_lim]);

        % replace -100 values with NaNs for the correlation
        parcel_data(parcel_data==-100)=NaN;
        parcel_data_thick_corr(parcel_data_thick_corr==-100)=NaN;
        spun_map = parcel_data(perm_id); % spin one of the maps of effects
        r_emp.Correlation(mom)=corr(parcel_data, parcel_data_thick_corr, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the effects
        % run permutation test
        r_perm = zeros(n_perm,1);
        for kk=1:n_perm
            r_perm(kk) = corr(spun_map(:, kk), parcel_data_thick_corr, ...
                'Rows', 'complete', 'Type', 'Pearson');
        end
        r_emp.p_value(mom) = sum(abs(r_perm(:)) >= abs(r_emp.Correlation(mom))) / n_perm; % p-value after spin test
    end

end

for supp_figure_13_14 = 1

    moments = ["Centre of gravity", "Variance"];
    % initialise table to store the correlations between the effect maps
    % with and without correcting for cortical thickness
    r_emp_GA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    r_emp_PNA = table(zeros(numel(moments),1), zeros(numel(moments),1), ...
        'RowNames', moments, 'VariableNames', ["Correlation", "p_value"]);
    % run models which contain both GA and PNA as predictors (effects
    % controlling for the effects of the other)
    for mom = 1:length(moments)
        if mom == 1
            cog_parcel_data = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_thick_corr = moment_age_model("cog", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 1);
        else
            var_parcel_data = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_thick_corr = moment_age_model("variance", ["GA", "PNA"], ...
                gen_table_economo, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 1);
        end
    end

    % calculate maximum absolute value for limits for each age-metric separately
    min_val_GA = min([min(cog_parcel_data(cog_parcel_data(:,1) > -100, 1)); ...
        min(cog_parcel_data_thick_corr(cog_parcel_data_thick_corr(:,1) > -100, 1)); ...
        min(var_parcel_data(var_parcel_data(:,1) > -100, 1)); ...
        min(var_parcel_data_thick_corr(var_parcel_data_thick_corr(:,1) > -100, 1))]);
    max_val_GA = max([max(cog_parcel_data(cog_parcel_data(:,1) < 100, 1)); ...
        max(cog_parcel_data_thick_corr(cog_parcel_data_thick_corr(:,1) < 100, 1)); ...
        max(var_parcel_data(var_parcel_data(:,1) < 100, 1)); ...
        max(var_parcel_data_thick_corr(var_parcel_data_thick_corr(:,1) < 100, 1))]);
    abs_lim_GA = max([abs(min_val_GA), abs(max_val_GA)]);
    abs_lim_GA = abs_lim_GA + abs_lim_GA/100;

    min_val_PNA = min([min(cog_parcel_data(cog_parcel_data(:,2) > -100, 2)); ...
        min(cog_parcel_data_thick_corr(cog_parcel_data_thick_corr(:,2) > -100, 2)); ...
        min(var_parcel_data(var_parcel_data(:,2) > -100, 2)); ...
        min(var_parcel_data_thick_corr(var_parcel_data_thick_corr(:,2) > -100, 2))]);
    max_val_PNA = max([max(cog_parcel_data(cog_parcel_data(:,2) < 100, 2)); ...
        max(cog_parcel_data_thick_corr(cog_parcel_data_thick_corr(:,2) < 100, 2)); ...
        max(var_parcel_data(var_parcel_data(:,2) < 100, 2)); ...
        max(var_parcel_data_thick_corr(var_parcel_data_thick_corr(:,2) < 100, 2))]);
    abs_lim_PNA = max([abs(min_val_PNA), abs(max_val_PNA)]);
    abs_lim_PNA = abs_lim_PNA + abs_lim_PNA/100;

    % plot the significant effects of GA and PNA on each moment
    for mom = 1:length(moments)
        if mom == 1
            parcel_data_GA = cog_parcel_data(:,1);
            parcel_data_GA_thick_corr = cog_parcel_data_thick_corr(:,1);
            parcel_data_PNA = cog_parcel_data(:,2);
            parcel_data_PNA_thick_corr = cog_parcel_data_thick_corr(:,2);
        else
            parcel_data_GA = var_parcel_data(:,1);
            parcel_data_GA_thick_corr = var_parcel_data_thick_corr(:,1);
            parcel_data_PNA = var_parcel_data(:,2);
            parcel_data_PNA_thick_corr = var_parcel_data_thick_corr(:,2);
        end

        vert_data_PNA = BoSurfStatMakeParcelData(parcel_data_PNA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA, wk40, strcat(moments(mom), ' PNA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_PNA, abs_lim_PNA]);
        vert_data_PNA_thick_corr = BoSurfStatMakeParcelData(parcel_data_PNA_thick_corr, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_PNA_thick_corr, wk40, strcat(moments(mom), ' PNA - thickness correction'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_PNA, abs_lim_PNA]);
        vert_data_GA = BoSurfStatMakeParcelData(parcel_data_GA, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA, wk40, strcat(moments(mom), ' GA'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_GA, abs_lim_GA]);
        vert_data_GA_thick_corr = BoSurfStatMakeParcelData(parcel_data_GA_thick_corr, wk40, wk40_economo_ind);
        figure; SurfStatViewData(vert_data_GA_thick_corr, wk40, strcat(moments(mom), ' GA - thickness correction'));
        colormap([0.5 0.5 0.5; vik; 0.5 0.5 0.5]);
        SurfStatColLim([-abs_lim_GA, abs_lim_GA]);

        % replace -100 values with NaNs for the correlation
        parcel_data_GA(parcel_data_GA==-100)=NaN;
        parcel_data_GA_thick_corr(parcel_data_GA_thick_corr==-100)=NaN;
        parcel_data_PNA(parcel_data_PNA==-100)=NaN;
        parcel_data_PNA_thick_corr(parcel_data_PNA_thick_corr==-100)=NaN;
        spun_map_GA = parcel_data_GA(perm_id); % spin one of the GA maps of effects
        spun_map_PNA = parcel_data_PNA(perm_id); % spin one of the PNA maps of effects
        r_emp_GA.Correlation(mom)=corr(parcel_data_GA, parcel_data_GA_thick_corr, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the GA effects
        r_emp_PNA.Correlation(mom)=corr(parcel_data_PNA, parcel_data_PNA_thick_corr, ...
            'Rows', 'complete', 'Type', 'Pearson'); % correlate the PNA effects
        % run permutation test
        r_perm_GA = zeros(n_perm,1);
        r_perm_PNA = zeros(n_perm,1);
        for kk=1:n_perm
            r_perm_GA(kk) = corr(spun_map_GA(:, kk), parcel_data_GA_thick_corr, ...
                'Rows', 'complete', 'Type', 'Pearson');
            r_perm_PNA(kk) = corr(spun_map_PNA(:, kk), parcel_data_PNA_thick_corr, ...
                'Rows', 'complete', 'Type', 'Pearson');
        end
        r_emp_GA.p_value(mom) = sum(abs(r_perm_GA(:)) ...
            >= abs(r_emp_GA.Correlation(mom))) / n_perm; % p-value after spin test
        r_emp_PNA.p_value(mom) = sum(abs(r_perm_PNA(:)) ...
            >= abs(r_emp_PNA.Correlation(mom))) / n_perm; % p-value after spin test
    end

end