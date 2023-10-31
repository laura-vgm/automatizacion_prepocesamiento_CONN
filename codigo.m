
clear all;
close all;
clc;

% FLUJO DE AUTOMATIZACIÓN DEL PREPROCESAMIENTO rs-fMRI EN CONN (provisional)
% es provisional ya que necesita mejoras, optimización y configuración de como se guardan los resultados.

ruta = pwd;                                                 % ruta actual (en donde se va a correr el código)
directorio_sujeto = dir(fullfile(ruta,'sub*'));             % lista de carpetas
directorio_sujeto = directorio_sujeto([directorio_sujeto.isdir]); % carpetas

NSUBJECTS = 1; % se deja establecidio en 1 sujeto, NO MODIFICAR, pues en cada archivo.mat va a 
% almacenar sólo un sujeto por tener diferente FOV (field of view)
% de igual forma si tienen igual FOV tampoco modificar porque no está
% configurado de esa forma por el momento

for i = 1:length(directorio_sujeto)
    sujeto_a = directorio_sujeto(i).name;     % nombre del sujeto
    sujeto_f = directorio_sujeto(i).name;     % nombre del sujeto
    ruta_sujeto_a = fullfile(ruta, sujeto_a); % ruta sujeto
    ruta_sujeto_f = fullfile(ruta, sujeto_f); % ruta sujeto
    ruta_anat = fullfile(ruta_sujeto_a, 'anat'); % ruta hasta anat
    ruta_func = fullfile(ruta_sujeto_f, 'func'); % ruta hasta func
    
    estructural = '*T1w.nii';       % para identificar el archivo estructural
    funcional = '*_bold.nii.gz';   % para identificar el archivo funcional

    files_estructural = dir(fullfile(ruta_anat, estructural)); % todo hasta el archivo
    files_funcional = dir(fullfile(ruta_func, funcional));     % todo hasta el archivo
    
    for j = 1:length(files_funcional)
        ruta_estructural = fullfile(ruta_anat, files_estructural(j).name); % ruta del archivo estructural
        ruta_funcional = fullfile(ruta_func,files_funcional(j).name);      % ruta del archivo funcional
    end
   
    FUNCTIONAL_FILE=cellstr(ruta_funcional);   % el siguiente código recibe la ruta en una cell
    STRUCTURAL_FILE=cellstr(ruta_estructural); % lo mismo para estructural

    % El código hasta aquí coge el archivo funcional y estructural de cada
    % sujeto y genera la ruta para utilizarla a continuación:

    if rem(length(FUNCTIONAL_FILE),NSUBJECTS),error('mismatch number of functional files %n', length(FUNCTIONAL_FILE));end
    if rem(length(STRUCTURAL_FILE),NSUBJECTS),error('mismatch number of anatomical files %n', length(FUNCTIONAL_FILE));end
    nsessions=length(FUNCTIONAL_FILE)/NSUBJECTS;
    FUNCTIONAL_FILE=reshape(FUNCTIONAL_FILE,[nsessions, NSUBJECTS]);
    STRUCTURAL_FILE={STRUCTURAL_FILE{1:NSUBJECTS}};
    disp([num2str(size(FUNCTIONAL_FILE,1)),' sessions']);
    disp([num2str(size(FUNCTIONAL_FILE,2)),' subjects']);
    TR=2.2; % Tiempo de repetición
     
    % CONN-SPECIFIC SECTION: RUNS PREPROCESSING/SETUP/DENOISING/ANALYSIS STEPS
    % Prepares batch structure
    clear batch;
    batch.filename=fullfile(ruta,['preprocesado_sub-0' num2str(i) '.mat']);  % New conn_*.mat experiment name
    
    % SETUP & PREPROCESSING step (using default values for most parameters, see help conn_batch to define non-default values)
    % CONN Setup                                            % Default options (uses all ROIs in conn/rois/ directory); see conn_batch for additional options 
    % CONN Setup.preprocessing                               (realignment/coregistration/segmentation/normalization/smoothing)
    batch.Setup.isnew=1;
    batch.Setup.nsubjects=NSUBJECTS;
    batch.Setup.RT=TR;                                        % TR (seconds)
    batch.Setup.functionals=repmat({{}},[NSUBJECTS,1]);       % Point to functional volumes for each subject/session
    for nsub=1:NSUBJECTS,for nses=1:nsessions,batch.Setup.functionals{nsub}{nses}{1}=FUNCTIONAL_FILE{nses,nsub}; end; end %note: each subject's data is defined by three sessions and one single (4d) file per session
    batch.Setup.structurals=STRUCTURAL_FILE;                  % Point to anatomical volumes for each subject
    nconditions=nsessions;                                  % treats each session as a different condition (comment the following three lines and lines 84-86 below if you do not wish to analyze between-session differences)
    if nconditions==1
        batch.Setup.conditions.names={'rest'};
        for ncond=1,for nsub=1:NSUBJECTS,for nses=1:nsessions,              batch.Setup.conditions.onsets{ncond}{nsub}{nses}=0; batch.Setup.conditions.durations{ncond}{nsub}{nses}=inf;end;end;end     % rest condition (all sessions)
    else
        batch.Setup.conditions.names=[{'rest'}, arrayfun(@(n)sprintf('Session%d',n),1:nconditions,'uni',0)];
        for ncond=1,for nsub=1:NSUBJECTS,for nses=1:nsessions,              batch.Setup.conditions.onsets{ncond}{nsub}{nses}=0; batch.Setup.conditions.durations{ncond}{nsub}{nses}=inf;end;end;end     % rest condition (all sessions)
        for ncond=1:nconditions,for nsub=1:NSUBJECTS,for nses=1:nsessions,  batch.Setup.conditions.onsets{1+ncond}{nsub}{nses}=[];batch.Setup.conditions.durations{1+ncond}{nsub}{nses}=[]; end;end;end
        for ncond=1:nconditions,for nsub=1:NSUBJECTS,for nses=ncond,        batch.Setup.conditions.onsets{1+ncond}{nsub}{nses}=0; batch.Setup.conditions.durations{1+ncond}{nsub}{nses}=inf;end;end;end % session-specific conditions
    end
    batch.Setup.outputfiles=[1,1,1,1,1,1]; % para que se creen los optional output files que se chulean antes de comenzar el preprocesamiento
    batch.Setup.preprocessing.steps='default_mni';
    batch.Setup.preprocessing.sliceorder='ascending';
    batch.Setup.preprocessing.art_thresholds=[5,0.9,1,1,1,0,3];
    batch.Setup.preprocessing.fwhm=6;
    batch.Setup.done=1;
    batch.Setup.overwrite='Yes';
    
    % uncomment the following 3 lines if you prefer to run one step at a time:
    % conn_batch(batch); % runs Preprocessing and Setup steps only
    % clear batch;
    % batch.filename=fullfile(cwd,'Arithmetic_Scripted.mat');            % Existing conn_*.mat experiment name
    
    % DENOISING step
    % CONN Denoising                                    % Default options (uses White Matter+CSF+realignment+scrubbing+conditions as confound regressors); see conn_batch for additional options 
    batch.Denoising.filter=[0.008, 0.09];                 % frequency filter (band-pass values, in Hz)
    batch.Denoising.done=1;
    batch.Denoising.overwrite='Yes';
    batch.Denoising.despiking=0;
    batch.Denoising.Detrending=1;

    
    % Generar los QA pl2023_09_29_094447253ots
    batch.QA.foldername = ruta;
    batch.QA.plots={'QA_NORM structural','QA_NORM functional','QA_NORM rois','QA_REG functional','QA_REG structural','QA_REG mni','QA_COREG functional','QA_TIME functional','QA_TIMEART functional','QA_DENOISE histogram','QA_DENOISE timeseries','QA_DENOISE FC-QC','QA_DENOISE scatterplot','QA_SPM design','QA_SPM contrasts','QA_SPM results','QA_COV'};

    
    % FIRST-LEVEL ANALYSIS step
    % CONN Analysis                                     % Default options (uses all ROIs in conn/rois/ as connectivity sources); see conn_batch for additional options 
    %batch.Analysis.done=1;
    %batch.Analysis.overwrite='Yes';
    
    % Run all analyses
    conn_batch(batch);
    
    % CONN Display
    % launches conn gui to explore results

%     conn
%     conn('load',fullfile(ruta,['preprocesado_sub-0' num2str(i) '.mat']));
%     conn gui_results

end


% Documentación de CONN batch: https://web.conn-toolbox.org/resources/documentation/conn_batch

% Tutorial de Andrew Jahn del Scripting (él lo hace todo en un mismo
% archivo.mat asumiendo igual FOV: https://www.youtube.com/watch?v=NJmPYLfE7oo&t=26s)

% por lo que este script realiza cada uno en un archivo diferente.

