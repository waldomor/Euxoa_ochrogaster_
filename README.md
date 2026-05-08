<h3><i>Euxoa ochrogaster</i> Guenée, 1852 repository</h3>

This repository was developed to predict <i>Euxoa ochrogaster</i> larvae outbreak in Manitoba state of Canada, through a deep learning architecture.
<br>
<br>

The scope of the Api.py code is to download the data from ERA5 (European Centre for Medium-Range Weather Forecasts, 2025), delay is adopted in order to comply with the terms, date have to be modified if necessary.
<br>
<br>
The scope of Multicollinearity_+PCA.r is to study the multicollinearity of different rasters, and conduct a PCA to select the final dataset.
<br>
<br>
The scope of Prediction_MLP+LSTM.py is to predict the outbreaks of <i>Euxoa ochrogaster</i> Guenée, 1852 larvae. It's necessary to use the species Extent of Occurrences shapefile cropped to Manitoba area, the species CSV, land cover of different crops as a raster, 
other rasters such as NDVI index, ERA5 soil temperature and soil mosture, soil texture. From this data will be conducted a standardization, assuming that have all same projection such as ESRI:54034.  
The PCA analysis is conducted for data selection. A training on the data is conducted using an Mpl model and Lstm model in order to assess the impact of climate variability, using a Python code. 
Pseudo absences are considered inside the Extent of Occurrence area, but also in a buffer zone around the main area according to literature data. 
The pseudo absences will be treated as positive unlabeled data (Bekker, 2020) and in training handled accordingly (reducing the bias). 
Cross-validation is performed, and the AUC is computed. In addition, accuracy, training loss, and validation loss are evaluated across training epochs. 
<br>
<br>
The scope of Resolution_enhancer.R is to enhance the resolution of rasters, using an interpolation process.
<br>
<br>
To use R code you need to install R software and R studio (matching the same version), and install terra package, as through CRAN. To use Python code you need to install Python and through pip install all the necessary libraries, present as import, through the terminal.
