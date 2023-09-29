#############################################################
# PACKAGES --------------------------------------------------
## These are the packages and addins used
#############################################################

install.packages("tidyverse")
install.packages("caTools")    # For Linear regression 
install.packages('car')        # To check multicollinearity 
install.packages("quantmod")
install.packages("MASS")
install.packages("corrplot")   # plot correlation plot
install.packages("pastecs") 
install.packages('moments')
library(moments)
library(pastecs)
library(caTools)
library(car)
library(quantmod)
library(MASS)
library(corrplot)
library(dplyr)
library(ggplot2)
library(tidyverse)
library(scales)

#############################################################
# LOAD DATA -------------------------------------------------

#############################################################
input_df <- try(read.csv("DataCoSupplyChainDataset.csv", header=TRUE, sep=','))

#############################################################
# VIEW DATA -------------------------------------------------
#############################################################
head(input_df)

tail(input_df)

str(input_df)


#############################################################
# COPY DATA -------------------------------------------------
## Comment: The aim is to work on the copy 
#############################################################
data <- data.frame(input_df)

tracemem(data) == tracemem(input_df)

#############################################################
# COLUMN NAMES ----------------------------------------------
## Two columns have similar names and can lead to confusion, renaming.
#############################################################
colnames(data)[colnames(data) == "Days.for.Shipping..real."] = "Days.For.Shipping.Real"

colnames(data)[colnames(data) == "Days.for.Shipping..scheduled."] = "Days.For.Shipping.Scheduled"

colnames(data)[colnames(data) == "Benefit.per.order"] = "Benefit.Per.Order"

colnames(data)[colnames(data) == "Sales.per.customer"] = "Sales.Per.Customer"

colnames(data)[colnames(data) == "Late_delivery_risk"] = "Late.Delivery.Risk"

colnames(data)[colnames(data) == "order.dat.DateOrders"] = "Order.Date.Date.Orders"

colnames(data)[colnames(data) == "shipping.date..DateOrders"] = "Shipping.Date.Date.Orders"

#############################################################
# MISSING VALUES --------------------------------------------
## Looking for any missing values and which column has them
#############################################################
any(is.na(data)) 

sapply(data, function(x) sum (is.na(x)))

## Product Description has 180519 missing values but its a column I wont use,
data$Product.Description <- NULL

sapply(data, function(x) sum (is.na(x)))

##Order Zipcode has 155679 but in our analysis it is a column I wont use,
data$Order.Zipcode <- NULL

sapply(data, function(x) sum (is.na(x)))


## In my analysis Customer Zip Code is a column I wont use but i need to show
## that I can deal with missing values.
data[is.na(data$Customer.Zipcode),]


## iterating through all the Customer address columns to find out which 
## exact address rows are associated with the missing zipcodes
i <- 0
for (value in data$Customer.Zipcode) {
  i <- i + 1
  if (is.na(value)){
    print(data$Customer.City[i])
    print(data$Customer.State[i])
    print(data$Customer.Country[i])
  }
}

## Trying to understand how important are these address rows to the overall addesses
## if i need to delete
aggregate(data$Customer.City ~ data$Customer.Country, data=data,FUN=function(x) length(unique(x)))

aggregate(data$Customer.State ~ data$Customer.City, data=data,FUN=function(x) length(unique(x)))

aggregate(data$Customer.City ~ data$Customer.State, data=data,FUN=function(x) length(unique(x)))

## trying to understand how important these row are to other departments like accounting
i <- 0
for (value in data$Customer.Zipcode) {
  i <- i + 1
  if (is.na(value)){
    print(data$Order.Status[i])
    print(data$Delivery.Status[i])
  }
}

## the zip codes in question are not that many to make a large impact if deleted
## but since it seems its an input error and the numeric is available in customer state
## I am going to make a swap of the values
data$Customer.Zipcode[is.na(data$Customer.Zipcode)] <- data$Customer.State[is.na(data$Customer.Zipcode)]

## check if it worked
data[is.na(data$Customer.Zipcode),]

## check if there are any other missing values
any(is.na(data))

#############################################################
# TYPE CASTING ----------------------------------------------
#############################################################
str(data)

data["Customer.Zipcode"] <- sapply(data["Customer.Zipcode"], as.numeric)

str(data)

#############################################################
# DELETE COLUMNS --------------------------------------------
## Deleting columns I will not use in the copy to make table more concise 
#############################################################
data$Customer.Email <- NULL

data$Customer.Password <- NULL

data$Longitude <- NULL

data$Latitude <- NULL

#############################################################
# FACTORS ---------------------------------------------------
## Using factors as part of the course to show I can
#############################################################
data["Type"] <- sapply(data["Type"], as.factor)

## Checking for using values in the columns to gather insights
str(data)
for(i in colnames(data)){
  if (is.character(data[,i])){
    cat("Unique values in", i, ":", unique(data[,i]), "\n")
  }
}

#############################################################
# EXPLORATORY ANALYSIS---------------------------------------
## Checking for min and max
#############################################################
for(i in colnames(data)){
  if (is.numeric(data[,i])){
    cat("In", i, "min is", min(data[,i]), "and Max is", max(data[,i]), "\n")
  }
}


## Building a correlation Matrix of the entire data to distill where to focus future models
## First select only data which is numeric
numeric_data <- select_if(data, is.numeric)

## Select all columns that do not contain the string Id
numeric_data <- numeric_data %>% select(-contains(".Id"))

## delete product status as it is not relevant
numeric_data$Product.Status <- NULL

## Find the Correlation of the remaining columns
cor_data <- round(cor(numeric_data), 2)

## Pivot the data to make it easier to read for plotting
pivot_data <- as.data.frame.table(cor_data, responseName = "value")

## Preview outcome
head(pivot_data)

## Plot correlation matrix
ggplot(data = pivot_data, 
       aes(x = Var1, 
           y = Var2, 
           fill = value)
) + geom_tile() + ggtitle("Correlation Matrix") +
  scale_x_discrete(guide = guide_axis(angle = 90))


##Initial Analysis through eye-balling graph
  ## Sales is correlated with 
  ## Order Item Discount
  ## Order item product price
  ## Order item total
  ## Product price
  ## Sales per Customer

#############################################################
# DATA PREPARATION ------------------------------------------
## From the results of the correlation matrix I am now going to 
## conduct a statistical analysis.
## The aim is to try and predict Sales through the correlating variables of
  ## Item Discount
  ## Item Product Price
  ## Item Total
  ## Product Price
  ## Sales per Customer
#############################################################
narrowed_data <- data.frame(
  data$Sales, 
  data$Order.Item.Discount, 
  data$Order.Item.Product.Price, 
  data$Order.Item.Total,
  data$Product.Price,
  data$Sales.Per.Customer
  )

#############################################################
# DESCREPTIVE STATISTICS-------------------------------------
#############################################################
res <- stat.desc(narrowed_data[, -5])

round(res, 2)

skewness(narrowed_data)

#############################################################
# SCALING ---------------------------------------------------
## To reduce variance.
#############################################################
narrowed_data <- data.frame(sapply(narrowed_data, function(x) scale(x, center = TRUE, scale = TRUE)))


#############################################################
# VISUALIZATION ---------------------------------------------
## Histogram of narrowed data to visualise spread of data
#############################################################
hist(narrowed_data$data.Sales, col="gold") 

hist(narrowed_data$data.Order.Item.Discount, col="gold")

hist(narrowed_data$data.Order.Item.Product.Price, col="gold")

hist(narrowed_data$data.Order.Item.Total, col="gold")

hist(narrowed_data$data.Product.Price, col="gold")

hist(narrowed_data$data.Sales.Per.Customer, col="gold")

#############################################################
# REGRESSION ------------------------------------------------
#############################################################
## Sales vs Item Product Price
plot(narrowed_data$data.Order.Item.Product.Price, narrowed_data$data.Sales, col="blue", ylab="Sales", xlab="Item Product Price", main="Sales Vs. Item Product Price")
abline(lm(narrowed_data$data.Sales~narrowed_data$data.Order.Item.Product.Price), col="red")

## Sales vs Product Price
plot(narrowed_data$data.Product.Price, narrowed_data$data.Sales, col="blue", ylab="Sales", xlab="Product Price", main="Sales Vs. Product Price")
abline(lm(narrowed_data$data.Sales~narrowed_data$data.Product.Price), col="red")

## Sales vs Order Item Total
plot(narrowed_data$data.Order.Item.Total, narrowed_data$data.Sales, col="blue", ylab="Sales", xlab="Order Item Total", main="Sales Vs. Order Item Total")
abline(lm(narrowed_data$data.Sales~narrowed_data$data.Order.Item.Total), col="red")

## Sales vs Order Item Discount
plot(narrowed_data$data.Order.Item.Discount, narrowed_data$data.Sales, col="blue", ylab="Sales", xlab="Discount", main="Sales Vs. Discount")
abline(lm(narrowed_data$data.Sales~narrowed_data$data.Order.Item.Discoun), col="red")

## Sales vs Sales Per Customer
plot(narrowed_data$data.Sales.Per.Customer, narrowed_data$data.Sales, col="blue", ylab="Sales", xlab="Sales Per Customer", main="Sales Vs. Sales Per Customer")
abline(lm(narrowed_data$data.Sales~narrowed_data$data.Sales.Per.Customer), col="red")

#############################################################
# COMPLEX MODEL ---------------------------------------------
#############################################################
model <- lm(
  narrowed_data$data.Sales ~ narrowed_data$data.Product.Price + 
    narrowed_data$data.Order.Item.Discount + 
    narrowed_data$data.Order.Item.Product.Price + 
    narrowed_data$data.Order.Item.Total + 
    narrowed_data$data.Sales.Per.Customer,
  data=narrowed_data
  )

## Summary of the model
summary(model)

## Summary of the Fit using Analysis of Variance Model
summary.aov(model)

## Plot Model to visually check the results
plot(model)

## Comment: My model seems to fit but is affected by outliers.

#############################################################
# MODEL OPTIMIZATION ----------------------------------------
## Reducing parameters to get a better fitting model.
## From our last analysis we see the Item Product Price and Sales Per Customer
## are not contributing to anything.
#############################################################
model <- update(model, . ~ . -narrowed_data$data.Order.Item.Product.Price)
model <- update(model, . ~ . -narrowed_data$data.Sales.Per.Customer)

## Summary of updated model.
summary(model)

## Summary aov
summary.aov(model)

## Plot model
plot(model)

## Model residuals
hist(model$residuals)

model_aov <- aov(
  narrowed_data$data.Sales ~ narrowed_data$data.Product.Price + 
    narrowed_data$data.Order.Item.Discount + 
    narrowed_data$data.Order.Item.Product.Price + 
    narrowed_data$data.Order.Item.Total + 
    narrowed_data$data.Sales.Per.Customer,
  data=narrowed_data
)

model_aov <- update(model, . ~ . -narrowed_data$data.Order.Item.Product.Price)
model_aov <- update(model, . ~ . -narrowed_data$data.Sales.Per.Customer)

hist(model_aov$residuals)

plot(model_aov)

#############################################################
# KOLMOGOROV-SMIRNOV TEST -----------------------------------
## Turned off warning about approximation of p-values during ties.
#############################################################
options(warn=-1) # Turn warning off to get a clean run for an image on my report
ks.test(narrowed_data$data.Sales, narrowed_data$data.Product.Price)

ks.test(narrowed_data$data.Sales, narrowed_data$data.Order.Item.Discount)

ks.test(narrowed_data$data.Sales, narrowed_data$data.Order.Item.Product.Price)

ks.test(narrowed_data$data.Sales, narrowed_data$data.Order.Item.Total)

ks.test(narrowed_data$data.Sales, narrowed_data$data.Sales.Per.Customer)
options(warn=0) #Turn warning on

#############################################################
# HETEROSKEDASTICITY ----------------------------------------
#############################################################
## Breusch-Pagan Test
lmtest::bptest(model)

## NCV Test
car::ncvTest(model)

#############################################################
# MULTICOLLINEARITY -----------------------------------------
## VIF Test 
#############################################################
vif(model)

#############################################################
# CORRELATION TEST ------------------------------------------
#############################################################
round(cor(narrowed_data),2)

#############################################################
# PREDICT ---------------------------------------------------
#############################################################
sales <- narrowed_data$data.Sales
product_price <- narrowed_data$data.Product.Price
order_item_discount <- narrowed_data$data.Order.Item.Discount
order_item_product_price <- narrowed_data$data.Order.Item.Product.Price
order_item_item_total <- narrowed_data$data.Order.Item.Total
sales_per_customer <- narrowed_data$data.Sales.Per.Customer

model <- lm(
  sales ~ product_price + 
    order_item_discount + 
    order_item_item_total,
)

predict.lm(model, data.frame(product_price = 360, order_item_discount=20, order_item_item_total=260))

#############################################################
# USER INTERFACE --------------------------------------------
#############################################################
predicted_sales <- function() {
  input_product_price <- (readline("What is the product price?:"))
  input_product_price <- as.numeric(input_product_price)
  input_order_item_discount <- (readline("What is the item discount on the product?:"))
  input_order_item_discount <- as.numeric(input_order_item_discount)
  input_order_item_total <- (readline("What is the total of all items?:"))
  input_order_item_total <- as.numeric(input_order_item_total)
  predict.lm(model, 
             data.frame(product_price = input_product_price, 
                        order_item_discount=input_order_item_discount, 
                        order_item_item_total=input_order_item_total)
             )
  }
predicted_sales()




