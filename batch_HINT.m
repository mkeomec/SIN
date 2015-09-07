function output = batch_HINT(subject_id, test_id)
test_id
% % DESCRIPTION:
%
%   Group Analysis script for HINT

%% INPUT PARAMETERS

% subject_id : four digit subject id number. ID numbers starting with 1 are
% from UW site. ID numbers starting with 2 are from Iowa site

% test_id : Enter, as specific as possible, test_id for group analysis

%% BEGIN LOOP. EACH CYCLE REPRESENTS A SUBJECT
for i=1:length(subject_id)
    
    %% BEGIN LOOP. EACH CYCLE REPRESENTS A TEST_ID
    for j=1:length(test_id)
        switch test_id(j)
            case {'HINT',}
            %% IDENTIFY TEST RESULT FILENAME
            test=test_id(j)
            ftest_id= strcat('*',test,'*')
            fullfile(num2str(subject_id(i)),char(ftest_id))
            filename=dir(fullfile(num2str(subject_id(i)),char(ftest_id)))

            %% LOAD DATA
            TestResults=load(filename.name);

            %% Turn off plotting to reduce computation time
            TestResults.results(1).RunTime.analysis.params.plot=0
            
            %% RUN ANALYSIS 
            ResultsOutput=analysis_HINT_test(TestResults,TestResults.results(1).RunTime.analysis.params);
            
            %% EXTRACT RTS
            rtsdata=[subject_id(i) ResultsOutput.analysis.results.rts]
            Subj_outputdata(i,1)=rtsdata(1)
            Subj_outputdata(i,j+1)=rtsdata(2)
            test_id_header(:,j)=test_id(j)
    
            case {'ANL,'}
                  
    end
    outputdata(i,:)=Subj_outputdata
    
end
        
%% 

% %% CREATE CVS FILE
% headers={'Subject_ID RTS' char(test_id_header(1)) char(test_id_header(2)) char(test_id_header(3)) char(test_id_header(4))}
% csvwrite(strcat('batch',test_id,'.csv'),headers)

filename = strcat('batch_HINT.csv');

fid = fopen(filename, 'w');
fprintf(fid, 'Subject_ID HINT_(SNR-50,ISTS) HINT_(SNR-50,SPSHN) HINT_(SNR-80,ISTS) HINT_(SNR-80,SPSHN)\n' );
fclose(fid)

dlmwrite(filename, outputdata, '-append', 'precision', '%.6f', 'delimiter', '\t');

% %% MULTI-STAGE TEST
% %   Most implementations of HINT are seen as two-stage tests. We want the
% %   scoring to be based of the last segment (typically)
% runtime = results(end).RunTime;

