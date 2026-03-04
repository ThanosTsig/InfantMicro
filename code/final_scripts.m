for init_project = 1

    GH           = '/Users/ttsigaras/Documents/GitHub'; % GitHub directory
    homeDir      = [GH '/InfantMicro'];

    wk40_tpl_dir = [homeDir '/tpl-week-40']; % week-40 template directory

    % add paths for GitHub directories (munesoft, SurfStat toolbox and gifti
    % toolbox)
    addpath(genpath([GH '/munesoft']))
    addpath(genpath([GH '/surfstat'])) 
    addpath(genpath([homeDir '/code']))
    addpath(genpath([homeDir '/gifti']))

    % load data
    load([homeDir, '/dHCP_gen_table.mat'], 'final_table', 'final_table_avg');
    load([homeDir, '/dHCP_parcel_MP.mat'], 'MP_dHCP_parc');
    load([homeDir, '/age_variables.mat'], 'age_vars');
    load([homeDir, '/dHCP_parcel_moments.mat'], 'dHCP_moments_parc');
    load([homeDir, '/dHCP_gen_table_schaefer200.mat'], 'final_table_schaefer200', 'final_table_avg_schaefer200')
    load([homeDir, '/dHCP_gen_table_no_twins.mat'], 'final_table_no_twins', 'final_table_avg_no_twins')

    uparc_economo = unique(final_table.parcel); % unique Von Economo parcel indices
    uparc_schaefer200 = unique(final_table_schaefer200.parcel); % unique Schaefer-200 parcel indices
    uparc_schaefer200(1) = [];
    excluded_indices_economo = [1, 15, 16, 17, 20, 21, 22, 23, 24, 25, 26, 45, ...
        59, 60, 61, 64, 65, 66, 67, 68, 69, 70]; % non-cortical and limbic  parcel indices
    total_num_parcels_economo = 88;
    total_num_parcels_schaefer200 = 201;
    valid_parcels_economo = setdiff(1:total_num_parcels_economo, ...
        excluded_indices_economo); % cortical and non-limbic parcel indices
    valid_parcels_schaefer200 = 2:201;
    depths = 1:12; % number of depths per profile

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
    load([GH '/munesoft/colourmaps/colorbrewer.mat'])
    scicol = [GH '/munesoft/colourmaps/ScientificColourMaps7'];
    scicol_names = ["devon", "lajolla", "lapaz", "roma", "vik"];
    for ii = 1:length(scicol_names)
        load(strcat(scicol, '/', scicol_names(ii), '.mat'));    
    end

   % load eigenmodes 2, 3 and 4
    eigenmodes = readmatrix([homeDir '/resources/week-40_pial_emode_2-4.txt']);
    % load previously used permutation indices
    load([homeDir '/resources/economo_spin_wk40.mat'], 'perm_id')

end

for figure_1 = 1

    for panel_A = 1

        GA = final_table_avg.GA;
        PNA = final_table_avg.PNA;
        PMA = final_table_avg.PMA;
        sex = final_table_avg.sex;
    
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
        scatter(final_table_avg.GA(final_table_avg.sex == 'F'), final_table_avg.PNA(final_table_avg.sex == 'F'), 50, 'filled', 'MarkerFaceColor', lajolla(75,:));
        scatter(final_table_avg.GA(final_table_avg.sex == 'M'), final_table_avg.PNA(final_table_avg.sex == 'M'), 50, 'filled', 'MarkerFaceColor', devon(80,:));
        set(gca, 'FontSize', 14);
        ylim([0 max(final_table_avg.PNA)]);
        xlim([min(final_table_avg.GA) max(final_table_avg.GA)])
        grid off;
        hold off;

        % plot smoothed histograms of PNA and GA distributions
        variables = {'GA', 'PNA'};
        for i = 1:length(variables)
            var = variables{i};
            [f1, xi1] = ksdensity(final_table_avg.(var)(final_table_avg.sex == 'M'), 'Bandwidth', 0.4);
            [f2, xi2] = ksdensity(final_table_avg.(var)(final_table_avg.sex == 'F'), 'Bandwidth', 0.4);
            figure('units','centimeters','outerposition',[0 0 28 8]); 
            hold on;
            plot(xi1, f1, 'Color', devon(80,:), 'LineWidth', 2);
            fill(xi1, f1, devon(80,:), 'FaceAlpha', 0.3);
            plot(xi2, f2, 'Color', lajolla(75,:), 'LineWidth', 2);
            fill(xi2, f2, lajolla(75,:), 'FaceAlpha', 0.3);
            set(gca, 'XTick', [], 'YTick', []);
            xlim([min(final_table_avg.(var)) max(final_table_avg.(var))]);
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
        avg_profile = mean(MP_dHCP_parc(:, :, :), [2, 3]);
        figure('units','centimeters','outerposition',[0 0 10 22]); 
        plot(avg_profile, -depth, 'Color', 'k', 'LineWidth', 1.5);
        set(gca, 'YTick', []);
        set(gca, 'FontSize', 14);
        grid off;

    end

    for panel_B = 1

        cmap = flipud(roma);
        nsubs = size(MP_dHCP_parc, 3);
        nbins = 100;

        for m = 1:2
            profiles_reshaped = reshape(MP_dHCP_parc, [12, ...
                total_num_parcels_economo * nsubs]); % reshape profile array
            moments_reshaped = reshape(dHCP_moments_parc(m,:,:), ...
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
        avg_moments = mean(dHCP_moments_parc, 3);
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
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            else
                var_sign_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
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
            SurfStatColLim([-abs_lim, abs_lim]);
        end

    end

    for panel_B_profile_plots = 1

        moments = ["Centre of gravity", "Variance"];
        PMA = final_table_avg.PMA;
        min_PMA = min(PMA);
        max_PMA = max(PMA);
        % define a window size of 1.5 weeks and 50% overlap
        window_size = 1.5;
        step = 0.75;
        ages = min_PMA:step:max_PMA;
        
        for mom = 1:length(moments)
            if mom == 1
                sign_parcel_data_PMA = moment_age_model("cog", "PMA", ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            else
                sign_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
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
            max_change_profs = MP_dHCP_parc(:,[max_change_parc ...
                sec_max_change_parc],:);
            min_change_profs = MP_dHCP_parc(:,[min_change_parc ...
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
                    depth_corrs(depth) = corr(squeeze(mean(profiles(depth,:,:),2)), final_table_avg.PMA);
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
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            else
                var_sign_parcel_data = moment_age_model("variance", ["GA", "PNA"], ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
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
            SurfStatColLim([-abs_lim, abs_lim]);
        end
    end

    for no_control = 1
        moments = ["Centre of gravity", "Variance"];
        % run individual models for GA and PNA as predictors (raw effects)
        for mom = 1:length(moments)
            if mom == 1
                cog_sign_parcel_data_GA = moment_age_model("cog", "GA", ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
                cog_sign_parcel_data_PNA = moment_age_model("cog", "PNA", ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
            else
                var_sign_parcel_data_GA = moment_age_model("variance", "GA", ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
                var_sign_parcel_data_PNA = moment_age_model("variance", "PNA", ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 1, 0);
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
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
                cog_parcel_data_GA_PNA = moment_age_model("cog", ["GA", "PNA"], ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            else
                var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
                var_parcel_data_GA_PNA = moment_age_model("variance", ["GA", "PNA"], ...
                    final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_no_twins = moment_age_model("cog", "PMA", ...
                final_table_no_twins, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_no_twins = moment_age_model("variance", "PMA", ...
                final_table_no_twins, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_no_twins = moment_age_model("cog", ["GA", "PNA"], ...
                final_table_no_twins, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data = moment_age_model("variance", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_no_twins = moment_age_model("variance", ["GA", "PNA"], ...
                final_table_no_twins, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_no_EPT = moment_age_model("cog", "PMA", ...
                final_table(final_table.GA >= 28, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA = moment_age_model("cog", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA_no_EPT = moment_age_model("cog", ["GA", "PNA"], ...
                final_table(final_table.GA >= 28, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_no_EPT = moment_age_model("variance", "PMA", ...
                final_table(final_table.GA >= 28, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA = moment_age_model("variance", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA_no_EPT = moment_age_model("variance", ["GA", "PNA"], ...
                final_table(final_table.GA >= 28, :), uparc_economo, ...
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_no_VPT = moment_age_model("cog", "PMA", ...
                final_table(final_table.GA >= 32, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA = moment_age_model("cog", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA_no_VPT = moment_age_model("cog", ["GA", "PNA"], ...
                final_table(final_table.GA >= 32, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_no_VPT = moment_age_model("variance", "PMA", ...
                final_table(final_table.GA >= 32, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA = moment_age_model("variance", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA_no_VPT = moment_age_model("variance", ["GA", "PNA"], ...
                final_table(final_table.GA >= 32, :), uparc_economo, ...
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_no_PT = moment_age_model("cog", "PMA", ...
                final_table(final_table.GA >= 37, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA = moment_age_model("cog", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_GA_PNA_no_PT = moment_age_model("cog", ["GA", "PNA"], ...
                final_table(final_table.GA >= 37, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_no_PT = moment_age_model("variance", "PMA", ...
                final_table(final_table.GA >= 37, :), uparc_economo, ...
                total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA = moment_age_model("variance", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_GA_PNA_no_PT = moment_age_model("variance", ["GA", "PNA"], ...
                final_table(final_table.GA >= 37, :), uparc_economo, ...
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PMA_schaefer200 = moment_age_model("cog", "PMA", ...
                final_table_schaefer200, uparc_schaefer200, ...
                total_num_parcels_schaefer200, valid_parcels_schaefer200, 0, 0);
        else
            var_parcel_data_PMA = moment_age_model("variance", "PMA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PMA_schaefer200 = moment_age_model("variance", "PMA", ...
                final_table_schaefer200, uparc_schaefer200, ...
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_schaefer200 = moment_age_model("cog", ["GA", "PNA"], ...
                final_table_schaefer200, uparc_schaefer200, ...
                total_num_parcels_schaefer200, valid_parcels_schaefer200, 0, 0);
        else
            var_parcel_data = moment_age_model("variance", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_schaefer200 = moment_age_model("variance", ["GA", "PNA"], ...
                final_table_schaefer200, uparc_schaefer200, ...
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
    for depth = 1:height(MP_dHCP_parc)
        % average intensities per parcel for each depth
        avg_intensities = mean(MP_dHCP_parc(depth, :, :), 3);
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_PNA = moment_age_model("cog", "PNA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
        else
            var_parcel_data_GA = moment_age_model("variance", "GA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_PNA = moment_age_model("variance", "PNA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_thick_corr = moment_age_model("cog", "PMA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 1);
        else
            var_parcel_data = moment_age_model("variance", "PMA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_thick_corr = moment_age_model("variance", "PMA", ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 1);
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
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            cog_parcel_data_thick_corr = moment_age_model("cog", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 1);
        else
            var_parcel_data = moment_age_model("variance", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 0);
            var_parcel_data_thick_corr = moment_age_model("variance", ["GA", "PNA"], ...
                final_table, uparc_economo, total_num_parcels_economo, valid_parcels_economo, 0, 1);
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