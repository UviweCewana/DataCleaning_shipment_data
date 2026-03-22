# DataCleaning_shipment_data
Data cleaning project on messy shipment data 

## Step 1: Removing Trailing/Leading spaces

<img width="2544" height="1576" alt="image" src="https://github.com/user-attachments/assets/c25d9d13-189e-4f63-acca-ddec9ab426bf" />

## Step 2 : Standardize Text Casting

<img width="2796" height="1576" alt="image" src="https://github.com/user-attachments/assets/095b3373-6bf3-40d7-890d-55110fe626b4" />
Handles inconsistent text by using 'INITCAP' to capitalise Destination cities, origin warehouses and carrier names while triming leading and trailing spaces

## Step 3 : Replace String 'NULL' and Handle true NULLS

<img width="3120" height="1828" alt="image" src="https://github.com/user-attachments/assets/e764e789-cc3e-47cb-bab6-c1b69c9ab76d" />

## Step 4 : Remove Duplicates

<img width="2508" height="2668" alt="image" src="https://github.com/user-attachments/assets/02a60101-44fc-4dce-9f40-cd1b355ec567" />

Step 5 : fixing negetive values and suspicious values
<img width="2440" height="1660" alt="image" src="https://github.com/user-attachments/assets/025f83af-5b1d-4daf-ae54-919ebf49988b" />

Eliminating negative weight values, as that would not be possible for any shipment and definding NULL values

## Step 6 : Validate Date Logic (DELIVERY AFTER SHIP DATE)

<img width="4912" height="2416" alt="image" src="https://github.com/user-attachments/assets/9ab430d1-062f-4fc9-aae8-9de8cff1d142" />

fixing date formats as there was inconsistencies and different formats reocrded and setting a data quality flag

## Step 7 : Detect & cap ouliers using percentiles (IQR)

<img width="4232" height="3844" alt="image" src="https://github.com/user-attachments/assets/3d79c0d3-006b-4528-985e-c4fc83236cd2" />


Full Query : Final Output
<img width="288" height="1080" alt="compressed_Snippet (1)" src="https://github.com/user-attachments/assets/58a3473d-04f2-4999-a975-7faa2450aa85" />

