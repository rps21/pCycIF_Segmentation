function [] = runSegmentation(parametersFile)   
%this function requires input of nuclei stack range. It assumes that every
%stack beyond that to the end is a cytoplasmic stain. Marker controlled
%watershed based on distance transform of nuclei channel is employed to
%separate nuclei clumps.

% Edit: added nuclei intensity measurement and removal of nuclei touching
% border 3/5/18

% Clarence Yapp 3/5/18


javaaddpath('/home/rps21/pCycIF_Segmentation/matlabDependencies/bioformats_package.jar')


%Reads file with input parameters, written in Matlab syntax
fid = fopen(parametersFile);
inputParams = textscan(fid, '%s', 'Delimiter', '', 'CommentStyle', '%');
fclose(fid);
%Evaluates and sets input parameters as Matlab varialbes
cellfun(@eval, inputParams{1});

%Set NucMaskChan from numCycles = 5;
NucMaskChan = 2:numCycles;


%Set input variables read from file
%Need to add error catching/messages
% inputPath = '/home/bobby/Dropbox/MATLAB/cardiotoxCycif/segmentation/pCycIF_Segmentation/insets_TxB';
% outputPath = '/home/bobby/Dropbox/MATLAB/cardiotoxCycif/segmentation/pCycIF_Segmentation/output';
% NucMaskChan = [2 5]; %Is this basically number of cycles? 2:cycle num
% row = ['B':'D'];   
% col = [2:5];
% SaveFig = 0;



for iRow = 1:numel(row)
    for iCol = 1:numel(col)
    files = dir([inputPath filesep  row(iRow) sprintf('%.2d', col(iCol)) '_*.tif']);
    numFiles = numel(files);
    
%     for iFile = 2:2:numFiles
    for iFile = 3:2:numFiles
        fileName = files(iFile).name;
        [pathstr,name,ext] = fileparts(fileName) ;
        
        I = volumeRead([inputPath filesep fileName]);
        nucleiStack = [2 size(I,3)/4];
        nucleiMaskChan = NucMaskChan;
        cytoChanRange = (size(I,3)-nucleiStack(2));
        cytoChanStart =size(I,3)/4+1;
        cytoChanEnd = size(I,3);
        
        nucleiImage = I(:,:,nucleiMaskChan(1):nucleiMaskChan(2));
        nucleiImage = sum(nucleiImage,3);
        nucleiImage=imgaussfilt(nucleiImage,1.2);
        

        %% background subtraction
        Ibh = imbothat(nucleiImage,strel('disk',10));
        I_bg = imsubtract(nucleiImage,Ibh);
%         imshow(I_bg,[])

        %% thresholding by Otsu
        I_bg(I_bg<0)=0;
        nucleiMask = I_bg>thresholdOtsu(I_bg);  
        %Dilation - new variable - imdilate
%         nucmask dila - subtract from cyto mask, replacing nuclei mask

%         imshowlinkedtrio(normalize(double(nuclei)),normalize(double(I_bg)),nucleiMask)

        %% process mask
        nucleiMask =bwareaopen(nucleiMask,30);
        nucleiMask = imfill(nucleiMask,'holes');
        nucleiMask = imclearborder(nucleiMask);
%         imshowlinkedtrio(normalize(double(nuclei)),normalize(double(I_bg)),nucleiMask)

        %% marker controlled watershed

        IdistTF =imcomplement(bwdist(~nucleiMask));
        dGauss = imgaussfilt3(IdistTF,2);
        dGauss = imhmin(dGauss,0.5);
        Imax = imregionalmin(dGauss);
%         imshowpair(nucleiImage,Imax)

        bw=nucleiMask;
        imgDist=-bwdist(~bw);
        imgDist=imimposemin(imgDist,Imax);
        imgDist(~bw)=-inf;
        imgLabel=watershed(imgDist);

        %tesselation
        markers =bwdist(imgLabel>1);
        waterMF=watershed(markers);
        nuclei = waterMF.*cast(imgLabel>1,class(waterMF));
        
%         figure,imshowpair(edge(nuclei>0),nucleiImage)

        %% cytoplasm segmentation
        cyto = I(:,:,cytoChanStart:end);
        cyto = sum(cyto,3);
        cytoOrig=cyto;
%         cyto=gather(gpuArray(medfilt2(cyto,[9 9])));    
        cytoth = imtophat(cyto,strel('disk',35));
        cytobh = 0;%imbothat(cyto,strel('disk',30));
        cyto_bg = cytoth-cytobh;

        cytoMask = cyto_bg>thresholdMinimumError(cyto_bg);
        cytoMask=imopen(cytoMask,strel('sphere',5));
        cytoMask=bwareaopen(cytoMask,200);
%         imshowLinkedTuple(sqrt(normalize(double(cyto))),sqrt(normalize(double(cyto_bg))),cytoMask)

        bgMask = uint16(imerode(~cytoMask,strel('disk',5)));
        
        cells=imclearborder(waterMF .* cast(cytoMask,class(waterMF)));%.*uint8(bwareaopen(waterMF .* uint8(cytoMask),500));


        %% eliminate empty cytoplasmic regions
        allCyto = bwlabel(cells>0);
        for i = 1:max(allCyto(:))
            if sum(sum(nucleiMask.*(allCyto == i))) ==0
                cells(allCyto==i)=0;
            end
        end
        
        for i = 1:max(nuclei(:))
            if sum(sum((nuclei==i).*(cells>0))) ==0
                nuclei(nuclei==i)=0;
            end
        end
        
        cytoplasm = cells-nuclei;
        %% Change here - imrode of ~2 pixels on cytoplasm 
%         imshowLinkedTuple(nuclei,cytoplasm,cells)
        
        %% measure intensities from regions
        meanIntNucTable = zeros(max(nuclei(:)),size(I,3));
        meanIntCytoTable = zeros(max(nuclei(:)),size(I,3));
        areaCytoTable = zeros(max(nuclei(:)),1);
        centroidCellTable = zeros(max(nuclei(:)),2);
        
        for iChan = 1: cytoChanEnd
            nucleiStats=regionprops(nuclei,I(:,:,iChan),'MeanIntensity','Centroid','Area');
            cytoStats=regionprops(cytoplasm,I(:,:,iChan),'MeanIntensity','Centroid','Area');
            
                 
            % generate mask for background subtraction
            bgChan= double(bgMask).*I(:,:,iChan);
            bgIntensity = mean(bgChan(:));            

            meanIntNucTable(:,iChan) = [nucleiStats.MeanIntensity]' - bgIntensity;
            %nuclei are given priority. If there are cytoplasm without
            %nuclei, they are ignored.
            matchCyto = intersect(unique(nuclei(:)),unique(cytoplasm(:)));
            for iCyto = 1:max(matchCyto(:))
                meanIntCytoTable(iCyto,iChan) = cytoStats(iCyto).MeanIntensity;
                areaCytoTable(iCyto) = cytoStats(iCyto).Area;
            end
            %
         
        end
  
        meanIntTable = [meanIntNucTable meanIntCytoTable];
        areaTable = [cat(1,nucleiStats.Area) areaCytoTable ];
        centroidCellTable = cat(1,nucleiStats.Centroid);                 
        
        %% write results to txt file
        if ~isempty(areaTable)
            variableNucNames = {};
            variableCytoNames = {};
            for ivarName = 1:size(meanIntTable,2)/2
                variableNucNames = cat(2,variableNucNames,{['NucleiChannel' int2str(ivarName)]});
                variableCytoNames = cat(2,variableCytoNames,{['CytoplasmChannel' int2str(ivarName)]});
            end

             writetable(array2table([meanIntTable areaTable centroidCellTable],'VariableNames',[variableNucNames variableCytoNames 'NucleusArea' 'CytoplasmArea' 'CellPosition_X' 'CellPosition_Y']),[outputPath filesep '_' name '_cytoMasked.txt'],'Delimiter','\t')
        end
        %% display
        if SaveFig==1
            cellEdge=edge(cells>0,'Sobel');
            nucleiEdge=edge(nuclei>0,'Sobel');
            allEdge= cellEdge + nucleiEdge;

            % add mask index to image
            figure,
            axs=[];
            axs = [axs subplot(1,2,1)];, imshow(sqrt(normalize(double(nucleiImage)))+edge(nuclei>0))
    
            for i =1:max(nuclei(:))
                text (nucleiStats(i).Centroid(1),nucleiStats(i).Centroid(2),int2str(i),'Color' ,'r')
            end

            axs = [axs subplot(1,2,2)];, imshow((sqrt(normalize(double(cytoOrig)))+allEdge))
            for i =1:max(cytoplasm(:))
                text (cytoStats(i).Centroid(1),cytoStats(i).Centroid(2),int2str(i),'Color' ,'r')
            end
            linkaxes(axs,'xy')


            savefig ([outputPath filesep '_' name '_cytoMasked.fig' ])
            unmaskedImage = I(:,:,2:end);
            allChan=[];
            for i = 1:size(unmaskedImage,3)
                allChan(:,:,i)  = 65000*(double(allEdge)+normalize((unmaskedImage(:,:,i))));
            end
            tiffwriteimj(uint16(allChan), [outputPath filesep '_' name '_cytoMasked' ext])
            close all
            disp(['Completed ' fileName])
        end
    end

    end
end

end
