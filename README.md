# Dockerized app for segmentation of plate-based Cyclic Immunofluorescence (pCycIF) imaging data

## Segmentation Methodology
The ability to accurately segment nuclei and cytoplasm can be confounded in images of densely packed cells. Using standard thresholding algorithms (such as Otsu thresholding which classifies pixels purely based on intesity relative to a single global threshold), are unlikely able to split the majority of cells into individual objects. Here, we employ a machine learning approach using a random forest model that is trained to classify pixels in the nuclei stain channel into 3 classes : 1) background, 2) nuclei contours, and 3) the center of the nuclei. The features that are extracted from the nuclei channel consist of derivatives, Laplacian of Gaussian, lcoal standard deviation, local entropy, Hough transforms, and steerable filters of various sizes. Each feature on its own is a terrible predictor, but when combined with others, results in making a significantly improved prediction. From the probability class for the nuclei centers, one can obtain the regional maxima, which are generally the center of each nuclei. These are used as markers for a marker-controlled watershed to split clumped nuclei apart. 
For segmenting the cytosol, we can employ 3 methods: 1) another random forest model trained on 2 classes (background and the junctions between cells), 2) the distance transform as an approximation of the cytosol, and 3) an annulus around each nuclei segmented using the aforementioned steps. Method 1 relies on whether there is an adequate marker that highlights the junctions between cells, such as B-catenin or E-cadherin. Where such as marker is absent, the distance transform (method 2) may yield satisfactory results. Method 3 samples a fixed area of the cytosol. 

## Installation
Make sure Docker is installed (https://www.docker.com/products/docker-desktop)
Download the docker image using the command `docker pull rps21/pcycif_segmentation`

To build from source, download the code using `https://github.com/sorgerlab/pCycIF_Segmentation.git`
Within Matlab, navigate to the pCycIF_Segmentation/segmentationCode folder.
Using Matlab's compilation functionality, run the command `mcc -m runSegmentation.m` to build the necessary binary
The binary can be run using Matlab Runtime (https://www.mathworks.com/products/compiler/matlab-runtime.html)
Alternatively, the code can be run by building a fresh docker container, using the Dockerfile contained in pCycIF_Segmentation/dockerBuild/Dockerfile which installs all necessary dependencies
Then follow the usage instructions below for using the Docker container 

## Usage 
Create an input folder which contains one folder for each plate that was imaged. Each of these folders must contain the images to be segmented
Example:
/localPath/Plate1/image1.tif
/localPath/Plate1/image2.tif
/localPath/Plate2/image1.tif

Create a configuration folder, containing the file pcycif_segmentation.yml
All configuration parameters must be set by the user and are explained below. Example configuration file can be found at 
https://github.com/sorgerlab/pCycIF_Segmentation/blob/master/dockerBuild/config/cycif_segmentation.yml

Run the docker container, indicating paths to the input images, configuration file, and desired output location
`docker run -v /local/path/to/config/:/config -v /local/path/to/input/:/input -v /local/path/to/output/:/output rps21/pcycif_segmentation`


# Application configuration and example 
A full example, as well as the segmentation source code, is contained in the associated github repository which can be cloned locally using:
git clone https://github.com/sorgerlab/pCycIF_Segmentation.git

## Input Data
Input data must be .tif image stacks, organized in folders by plate imaged. 
Example data can be found at: /localPath/pCycIF_Segmentation/dockerBuild/input

## Segmentation Output
Output folder must be specified, and can correspond to any already created local folder. Output files consist of...
Example output can be found at:/localPath/pCycIF_Segmentation/dockerBuild/output


## Configuration parameters
The following parameters must be set by the user based on their experimental design. 
Example configuration file can be found at: /localPath/pCycIF_Segmentation/dockerBuild/config

parallel: Boolean value (0/1) determining if segmentation will be run in parallel
Example: 0
NucMaskChan: Matrix with numbered index of first and last image of tiff stack that correspond to nuclear stains
Example: [1 9]
CytoMaskChan: Matrix with numbered index of first and last image of tiff stack that correspond to cytoplasmic stains
Example: [10 36]
numCycles: Number value corresponding to the number of cycles
Example: 9
row: String containing the lettered index corresponding to the first and last row of a 96-well plate to segment 
Example: 'CE'
col: Matrix with numbered index of first and last column  of a 96-well plate to segment
Example: [4 10]
saveFig: Boolean value (0/1) determining if you want to save Matlab .fig files 
Example: 1
cytoMethod: Cytoplasm segmentation method to use. Options:
Example: 'RF'
MedianIntensity: 1
saveMasks: Boolean value (0/1) determining if you want to save mask images
Example: 1
applyFFC: String defining flat feel correction to use. Options:'none', 'ffonly'
Example: 'ffonly'
useRFNuc: Boolean value (0/1) determining if you want to use... ?
Example: 1
segmentCytoplasm: 'segmentCytoplasm'
bleachImaged: Boolean value (0/1) stating if images were taked of bleaching in between each cycle 
Example: 0
markerList: List of strings indicating the names of biomarkers used, ordered by Channel and cycle number (Channel 1 - Cycle 1-end, Channel 2 - Cycle 1-end, etc. If no list is provided, channel and cycle names will be used instead
Example: []

