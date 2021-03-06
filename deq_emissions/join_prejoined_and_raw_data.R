library(dplyr)
library(tidyr)

#####
# Step 0 - Read in Data
#####
setwd("~/Desktop/Portland_Clean_Air/deq_emissions/")

co_details <- read.csv("prejoined_data//2016_co_details.tsv", sep="\t",
                     stringsAsFactors = F,
                     header = F,
                     quote = "",
                     col.names = c("company_source_no",
                                   "addr_hash_pt1",
                                   "addr_hash_pt2",
                                   "addr_hash_pt3",
                                   "addr_hash_pt4",
                                   "addr_hash_pt5",
                                   "emi_hash_pt1",
                                   "emi_hash_pt2",
                                   "mat_hash_pt1",
                                   "mat_hash_pt2"))


emi_agg <- read.csv("prejoined_data/2016_emi_agg.tsv", sep = "\t", fill = T,
                    header = F,
                    stringsAsFactors = F,
                    col.names = c("row_id", "units_id", 
                                  "emi_agg_amt_1", "emi_agg_unit_1", "emi_agg_unit_1_desc",
                                  "emi_agg_amt_2", "emi_agg_unit_2", "emi_agg_unit_2_desc", 
                                  "emi_agg_unclear_a", "emi_agg_unclear_b", "emi_agg_unclear_c"))
emi_agg$row_id <- as.integer(emi_agg$row_id)

mat_agg <- read.csv("prejoined_data/2016_mat_agg.tsv", sep = "\t", fill = T,
                    header = F, 
                    stringsAsFactors = F,
                    col.names = c("row_id", "units_id", 
                                 "mat_agg_1", "mat_agg_2", "mat_agg_3",
                                 "mat_agg_4", "mat_agg_5", "mat_agg_6",
                                 "mat_agg_7", "mat_agg_8", "mat_agg_9", 
                                 "mat_agg_10"))
mat_agg$row_id <- as.integer(mat_agg$row_id)

emi_desc <- read.csv("prejoined_data/2016_emi_desc.tsv", sep = "\t", fill = T, 
                     quote = "", 
                     header = F, 
                     stringsAsFactors = F,
                     col.names = c("row_id", "units_id", 
                                   "desc_col_1", "desc_col_2", "desc_col_3"))

mat_desc <- read.csv("prejoined_data/2016_mat_desc.tsv", sep = "\t", fill = T,
                     header = F,
                     stringsAsFactors = F,
                     col.names = c("row_id", "units_id",
                                   "desc_col_1", "desc_col_2", "desc_col_3", "desc_col_4"))


emi_chem <- unique(read.csv("raw_data/2016_emi_chem.tsv", sep = "\t", header = F, stringsAsFactors = F))
mat_chem <- read.csv("raw_data/2016_mat_chem.tsv", sep = "\t", header = F, stringsAsFactors = F, 
                     colClasses = c("character"))
row_lookup <- read.csv("raw_data/2016_row_lookup.tsv", 
                       sep = "\t", 
                       header = F, 
                       quote = "", 
                       stringsAsFactors = F,
                       col.names = c("row_id", "other_row_id", "chem_id_array", "sheet_key", "co_sourc_no", "file_name"))
units <- read.csv("raw_data/2016_units.tsv", sep = "\t", header = F, stringsAsFactors = F, 
                  col.names = c("units_id", "col_headers", "last_descriptor_column"))

######
# Step 1 - Get all companies with and split the EMI and MAT into two data sets.
######
co_details %>%
  mutate(address = paste(addr_hash_pt3, addr_hash_pt4, addr_hash_pt5, sep = ", ")) %>%
  filter(emi_hash_pt1 == "true")-> co_details_emi

co_details %>%
  mutate(address = paste(addr_hash_pt3, addr_hash_pt4, addr_hash_pt5, sep = ", ")) %>%
  filter(mat_hash_pt1 == "true")-> co_details_mat

#####
# Step 2 - Pull In Row Info
#####
#clean up row lookup table from having array to having a column
row_lookup %>%
  separate_rows(., chem_id_array, sep = ",") %>%
  mutate(chem_id_array = gsub('\\"|\\[|\\]', '',chem_id_array)) %>%
  mutate(chem_id_array = trimws(chem_id_array)) -> row_lookup_exploded

row_lookup_exploded %>%
  filter(sheet_key == "EMI") -> row_lookup_emi
row_lookup_exploded %>%
  filter(sheet_key == "MAT") -> row_lookup_mat

left_join(co_details_emi, row_lookup_emi, by = c("company_source_no" = "co_sourc_no")) -> co_details_emi
left_join(co_details_mat, row_lookup_mat, by = c("company_source_no" = "co_sourc_no")) -> co_details_mat

#####
# Step 3 - Pull in All Data
#####
left_join(co_details_emi, emi_desc, by = c("row_id" = "row_id")) -> co_details_emi
left_join(co_details_emi, emi_agg, by = c("row_id" = "row_id")) -> co_details_emi
co_details_emi %>% mutate(units_id = coalesce(units_id.x, units_id.y)) %>%
  select(-units_id.x, -units_id.y) -> co_details_emi
left_join(co_details_emi, emi_chem, by = c("chem_id_array" = "V1")) -> co_details_emi
left_join(co_details_emi, units, by = c("units_id" = "units_id")) -> co_details_emi

left_join(co_details_mat, mat_desc, by = c("row_id" = "row_id")) -> co_details_mat
left_join(co_details_mat, mat_agg, by = c("row_id" = "row_id")) -> co_details_mat
co_details_mat %>% mutate(units_id = coalesce(units_id.x, units_id.y)) %>%
  select(-units_id.x, -units_id.y) -> co_details_mat
left_join(co_details_mat, mat_chem, by = c("chem_id_array" = "V1")) -> co_details_mat
left_join(co_details_mat, units, by = c("units_id" = "units_id")) -> co_details_mat

#####
# Step 4 - Add a flag for all rows with filter
##### 
### EMI First
no_control_device_phrases <- c("0", "0.0", "None", NA, "none", "N/A", "Uncontrolled", "--", "", 
                               "NONE", "uncontrolled", "uncontroled", "No control", "n/a")
co_details_emi %>%
  mutate(control_device_info_a = emi_agg_unclear_a) %>%
  mutate(control_device_info_b = emi_agg_unclear_b) %>%
  mutate(has_control_device = ifelse(control_device_info_a %in% no_control_device_phrases, 0, 1)) %>%
  mutate(has_control_device = ifelse(control_device_info_b > 0, 1, has_control_device)) %>%
  mutate(has_control_device = ifelse(is.na(has_control_device), 0, has_control_device)) %>%
  mutate(emissions_2016_lbs = V9) %>%
  mutate(emissions_pollutant = V5) -> co_details_emi

### MAT Second
co_details_mat %>%
  mutate(control_device_info_a = mat_agg_8) %>%
  mutate(control_device_info_b = mat_agg_9) %>%
  mutate(has_control_device = ifelse(control_device_info_a %in% no_control_device_phrases, 0, 1)) %>%
  mutate(has_control_device = ifelse(control_device_info_b > 0, 1, has_control_device)) %>%
  mutate(has_control_device = ifelse(is.na(has_control_device), 0, has_control_device)) %>%
  mutate(materials_2016_lbs = V9) %>%
  mutate(material_pollutant = V5) -> co_details_mat

#####
# Step 5 - Add a flag for a heavy metals
#####

heavy_metals_string <- tolower(paste(read.csv("raw_data/heavy_metals.tsv", header = F, stringsAsFactors = F)$V1, collapse="|"))
co_details_emi %>% 
  mutate(is_heavy_metal = grepl(heavy_metals_string, emissions_pollutant, ignore.case = T)) -> co_details_emi

##### 
# Step 6 - Create Summary Data Sets + write the output
##### 
# script to generate this data set is look_up_counties.R
counties <- read.csv("prejoined_data/address_to_country_lookup.csv", stringsAsFactors = F)
left_join(co_details_emi, counties, by = ("address" = "address")) -> co_details_emi

##### 
# Step 7 - Create Summary Data Sets + write the output
##### 

co_details_emi %>%
  filter(has_control_device == 0) -> co_details_emi_uncontrolled_only

co_details_emi_uncontrolled_only  %>%
  group_by(company_source_no, addr_hash_pt2, addr_hash_pt4, address, county) %>%
  summarise(total_unfiltered_emissions = sum(as.numeric(emissions_2016_lbs), na.rm = T),
            total_unfiltered_emissions_heavy_metals_only = sum(ifelse(is_heavy_metal,as.numeric(emissions_2016_lbs), 0), na.rm =T)) %>%
  arrange(-total_unfiltered_emissions) %>%
  rename(company_name = addr_hash_pt2) %>%
  rename(city = addr_hash_pt4) -> total_uncontrolled_emissions_by_company

total_uncontrolled_emissions_by_company %>%
  ungroup() %>%
  mutate(total_emissions_rank_state = dense_rank(desc(total_unfiltered_emissions))) %>% 
  mutate(heavy_metals_emissions_rank_state = dense_rank(desc(total_unfiltered_emissions_heavy_metals_only))) %>%
  mutate(total_emissions_rank_mult_wash_clack = dense_rank(desc(ifelse(
    county %in% c("Multnomah County", "Washington County", "Clackamas County"), total_unfiltered_emissions, 0
  )))) %>% 
  mutate(total_emissions_rank_mult_wash_clack = ifelse(
    county %in% c("Multnomah County", "Washington County", "Clackamas County"), total_emissions_rank_mult_wash_clack, NA
  )) %>% 
  mutate(heavy_metals_emissions_rank_mult_wash_clack = dense_rank(desc(ifelse(
    county %in% c("Multnomah County", "Washington County", "Clackamas County"), total_unfiltered_emissions_heavy_metals_only, 0
  )))) %>% 
  mutate(heavy_metals_emissions_rank_mult_wash_clack = ifelse(
    county %in% c("Multnomah County", "Washington County", "Clackamas County"), heavy_metals_emissions_rank_mult_wash_clack, NA
  )) %>% 
  mutate(total_emissions_rank_state = ifelse(total_unfiltered_emissions > 0, total_emissions_rank_state, NA)) %>% 
  mutate(heavy_metals_emissions_rank_state = ifelse(total_unfiltered_emissions_heavy_metals_only > 0, heavy_metals_emissions_rank_state, NA)) %>% 
  mutate(total_emissions_rank_mult_wash_clack = ifelse(total_unfiltered_emissions > 0, total_emissions_rank_mult_wash_clack, NA)) %>% 
  mutate(heavy_metals_emissions_rank_mult_wash_clack = ifelse(total_unfiltered_emissions_heavy_metals_only > 0, heavy_metals_emissions_rank_mult_wash_clack, NA)) %>% 
  filter(total_unfiltered_emissions > 0) -> total_uncontrolled_emissions_by_company

write.csv(co_details_emi, file = "output_data/2016_all_emissions.csv", row.names = F)
write.csv(co_details_emi_uncontrolled_only, file = "output_data/2016_emissions_uncontrolled_only_detailed_data.csv", row.names = F)
write.csv(total_uncontrolled_emissions_by_company, file = "output_data/2016_uncontrolled_emissions_summary.csv", row.names = F)

# we're ignoring materials for now
