function output = batch_HINT(subject_id, test_id)
test_id
% % DESCRIPTION:
%
%   Group Analysis script for HINT

<<<<<<< HEAD
%% INPUT PARAMETERS

% subject_id : four digit subject id number. ID numbers starting with 1 are
% from UW site. ID numbers starting with 2 are from Iowa site

% test_id : Enter, as specific as possible, test_id for group analysis

=======
%% GET INPUT PARAMETERS

% d=varargin2struct(varargin{:});

% %% IS THIS AN OPTIONS STRUCTURE
% %   If not, then force it to look like one.
% if ~isfield(d, 'subject')
%     d = SIN_TestSetup('Defaults', d.subjectID); 
% end % isstruct
% 
% % Set defaults
% if ~isfield(d, 'regexp'), d.regexp = '.mat'; end
% 
% %% GET TEST INFORMATION
% all_tests = regexpdir(d.subject.subjectDir, d.regexp, false);
>>>>>>> 4205088e8445f23ddfb8cf52af05547632a0a960
%% BEGIN LOOP. EACH CYCLE REPRESENTS A SUBJECT
for i=1:length(subject_id)
    
    %% BEGIN LOOP. EACH CYCLE REPRESENTS A TEST_ID
    for j=1:length(test_id)
<<<<<<< HEAD
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
                  
=======
        %% IDENTIFY TEST RESULT FILENAME
        test=test_id(j)
        
        ftest_id= strcat('*',test,'*')
       fullfile(num2str(subject_id(i)),char(ftest_id))
        filename=dir(fullfile(num2str(subject_id(i)),char(ftest_id)))


        % %% CREATE FILENAMES BASED ON subject_id AND test_id
        % 
        % sub_id=num2str(subject_id(i))
        % prefilename= strcat(sub_id,'-',test_id,'*')
        % prefilename=dir(prefilename)
        % filename=prefilename.name

        %% LOAD DATA
        TestResults=load(filename.name);

        %% RUN ANALYSIS 

        ResultsOutput=analysis_HINT_test(TestResults,TestResults.results(1).RunTime.analysis.params);

        %% EXTRACT RTS
        rtsdata=[subject_id(i) ResultsOutput.analysis.results.rts]
        Subj_outputdata(i,1)=rtsdata(1)
        Subj_outputdata(i,j+1)=rtsdata(2)
        test_id_header(:,j)=test_id(j)
        
>>>>>>> 4205088e8445f23ddfb8cf52af05547632a0a960
    end
    outputdata(i,:)=Subj_outputdata
    
end
        
%% 

% %% CREATE CVS FILE
<<<<<<< HEAD
% headers={'Subject_ID RTS' char(test_id_header(1)) char(test_id_header(2)) char(test_id_header(3)) char(test_id_header(4))}
=======
headers={'Subject_ID RTS' char(test_id_header(1)) char(test_id_header(2)) char(test_id_header(3)) char(test_id_header(4))}
>>>>>>> 4205088e8445f23ddfb8cf52af05547632a0a960
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

