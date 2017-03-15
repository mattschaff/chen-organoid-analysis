function [ChenConnectivityAnalysis] = ChenConnectivityAnalysis(directory_path, data_path, only_active_neurons)
%Computes functional network analysis metrics
    %input parameters
    if exist('directory_path', 'var') == 0
        error('Directory Path input parameter is not set.');
    end
    if exist('data_path', 'var') == 0
        error('Data Path input parameter is not set.');
    end
    if exist('only_active_neurons', 'var') == 0
        only_active_neurons = 0;
    end
    %load test data
        % CROSS CORRELATION OUTPUT
            % Explanation: Matrix of the largest pair-wise correlation (r values) between neurons' firing ...
            % ... across discrete units of lag time.
                % - This is the matrix output from the FC cross correlation from FluoroSNNAP
                % - BCT analysis requires an FC matrix of some sort 
                % - This cross-corr method randomly generates fluorescent traces based on spike times ...
                % ... then correlates these traces between 2 neurons across discrete units of lag time.
                % - I don't understand why FluoroSNNAP does not use the raw fluorescence traces.
            load(data_path);
            fc_matrix = C;
    % only active neurons 
    if only_active_neurons == 1
        fc_matrix( all(~fc_matrix,2), : ) = [];
        fc_matrix( :, all(~fc_matrix,1) ) = [];
    end
    % add BCT to MATLAB path
        addpath('BCT_code');
    %initialize variables
         % we need this for path & centrality calculations
    %metrics of interest
        output = struct();
        %DENSITY
            % Explanation: Density is the fraction of present connections to possible connections.
                % note --> it's all about nonzero FC matrix elements
                % # present connections = # nonzero matrix elements in top triangle of connection matrix 
                % # possible connections = ((matrix size)^2 - (matrix size))/2
                    % note: cannot count self-connections (that's why matrix size is subtracted)
                % vertices => matrix size
                % edges => # nonzero matrix elements in top triangle of connection matrix
            % Execution
            [output.density,output.vertices,output.edges] = density_und(fc_matrix);
        %DEGREE DISTRIBUTION
            % Explanation: Degree per cell is the number of connections it has within the network
                % Simply, this is the sum of pair-wise connections (FC matrix elements) between Cell 1 and all ... 
                % ... other cells that are not zero.
                % This would be sensitive to a threshold we could set in generating the FC matrix.
            output.degree_distribution = degrees_und(fc_matrix);
            output.degree_avg = mean(output.degree_distribution); 
            output.degree_avg_normalized = output.degree_avg/size(fc_matrix,1);  
        %CLUSTERING COEFFICIENT
            % Explanation: Average intensity of all triangles associated with each node. (fxnal integration measure)
                % Computed according to Equation 9 defined in Onnela et al. 2005
                % For each cell, it multiplies weights of connections to two other cells, then sums these per cell, ...
                % ... then divides by k(k-1), where k = the degree (defined above)
                % dividing by k(k-1) effectively scales the sum of intensity into an average per cell
            [C_pos,C_neg,output.average_clustering_coeff,Ctot_neg] = clustering_coef_wu_sign(fc_matrix,1);
            output.clustering_coeff_distribution = clustering_coef_wu(fc_matrix);
        %MODULARITY
            [Ci output.modularity] = modularity_und(fc_matrix);
        %CHARACTERISTIC PATH
            % Explanation: Average path between all nodes in network (fxnal segregation measure)
                % A path between two nodes is the inverse of the connectivity weight (1/weight).
                % A shorter path means two nodes are better connected.
                % Therefore, we must first convert the FC matrix into a 'distance' matrix of paths.
                % All the nonzero, nonNaN paths between all nodes are then averaged into one number.
            distance_matrix = weight_conversion(fc_matrix,'lengths');
            D = distance_matrix; % let's get rid of zero columns
            D( all(~D,2), : ) = [];
            D( :, all(~D,1) ) = [];
            [output.chracteristic_path, output.global_efficiency] = charpath(D);
        %GLOBAL EFFICIENCY
            % Explanation: Average inverse of characteristic path for all nodes in the network (fxnal segregation measure)
            %output.global_efficiency = mean(1./D);    
        %BETWEENNESS CENTRALITY
            % Explanation: Fraction of paths in network that contain each node
                % The nodes with greatest centrality are "hub" nodes
                % The algorithm finds the number of all shortest paths between every set of two nodes that ...
                % ...passes through any one node. The greater number of paths through the node, the greater centrality
                % PROBLEM: Our centrality ouptut only shows lots of zero entries...I would expect all values to have ...
                % ...nonzero entries. I will consider reaching out to the algorithm creator.
            B = betweenness_wei(distance_matrix);
            %must normalize
            n = numel(fc_matrix);
            output.betweenness = B./((n-1)*(n-2));
        %save output;
            t = datetime([], [], []);
            t = datetime('now','TimeZone','local','Format','d-MM-y_HH_mm_ss');
            mkdir(strcat(directory_path,char(t)));
            csvwrite(strcat(directory_path,char(t), '/degree_distribution.csv'), output.degree_distribution);
            csvwrite(strcat(directory_path,char(t), '/clustering_coeff_distribution.csv'), output.clustering_coeff_distribution);
            csvwrite(strcat(directory_path, char(t), '/betweenness.csv'), output.betweenness);
            output2 = output;
            output2.degree_distribution = 'double';
            output2.clustering_coeff_distribution = 'double'; 
            output2.betweenness = 'double';
            temp_table = struct2table(output2);
            writetable(temp_table,strcat(directory_path,char(t),'/network_summary.csv'));
end

