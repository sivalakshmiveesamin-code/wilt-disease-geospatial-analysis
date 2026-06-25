getwd()
setwd("C:/DARP")
library(dplyr)
library(ggplot2)
library(reshape2)
library(corrplot)
library(caret)
library(randomForest)
library(rpart)
library(rpart.plot)

wilt_data <- read.csv("wilt_master_dataset.csv")

wilt_data$class <-as.factor(wilt_data$class)


## Exploratory Data Analysis and Visualization

summary_stats <- wilt_data %>%
  group_by(class) %>%
  summarise(
    Avg_NIR = mean(Mean_NIR),
    Avg_Green = mean(Mean_Green),
    Total_Count = n()
  )

# The imbalance

ggplot(wilt_data, aes(x = class, fill = class)) +
  geom_bar(color = "black")+
  geom_text(stat = 'count', aes(label = ..count..), vjust = -0.5, size = 5) +
  labs(title = "Class Imbalance in Wilt Dataset",
       x = "Tree Health Status",
       y = "Number of Observations") +
  scale_fill_manual(values = c("Healthy" = "lightgreen", "Wilt" = "tomato"))+
  theme_minimal()

# Spectral boxplots

spectra_data <- melt(wilt_data,
                     id.vars = "class",
                     measure.vars = c("Mean_NIR", "Mean_Red", "Mean_Green"))

ggplot(spectra_data, aes(x = variable, y = value, fill = class))+
  geom_boxplot(alpha = 0.8, outlier.shape = 1) +
  labs(title = "Light Spectrum Comparisions: Health vs. Wilt Trees",
       x = "Light Spectrum Band",
       y = "Satellite Measurement Value") +
  scale_fill_manual(values = c("Healthy" = "lightgreen", "Wilt" = "tomato"))+
  theme_minimal()

# Correlation heat maps

numeric_vars <- wilt_data[, c("GLCM_pan", "Mean_Green", "Mean_Red", "Mean_NIR", "SD_pan")]

cor_matrix <- cor(numeric_vars)

corrplot(cor_matrix,
         method = "color",
         type = "upper",
         addCoef.col = "black",
         tl.col = "black",
         tl.srt = 45,
         title = "Correlation Heatmap of Satellite Variables",
         mar = c(0, 0, 1, 0))

print("--- Class Topic: Confidence intervals using lm() ---")

collinearity_model <- lm(Mean_Red ~ Mean_Green, data = wilt_data)

# Print the summary of the linear model
summary(collinearity_model)


print("Confidence Intervals for the Linear Model:")
confint(collinearity_model)

## Hypothesis testing
t.test(Mean_Red ~ class, data = wilt_data)
t.test(Mean_Green ~ class, data = wilt_data)

print("--- Class Topic: Confidence interval for population mean ---")

nir_ttest <- t.test(Mean_NIR ~ class, data = wilt_data)
print("T-test: Mean NIR for Healthy vs. Wilt")
print(nir_ttest)

print("95% Confidence Interval for the difference in means (NIR):")
print(nir_ttest$conf.int)
#Phase 3

clean_wilt <- wilt_data[, !(names(wilt_data) %in% c("Mean_Red"))]

train_data <- clean_wilt %>% filter(source == "train")
test_data <- clean_wilt %>% filter(source == "test")

train_data$source <- NULL
test_data$source <- NULL

print("Original Training Data Imbalance:")
print(table(train_data$class))



set.seed(123)
balanced_train_data <- upSample(x = train_data[, !(names(train_data) == "class")],
                                y = train_data$class,
                                yname = "class")

print("New Perfectly Balanced Training Data:")
print(table(balanced_train_data$class))

set.seed(123)
rf_model <- randomForest(class ~ .,
                         data = balanced_train_data,
                         importance = TRUE,
                         ntree = 500)

print("How important is each variable?")
print(importance(rf_model))

varImpPlot(rf_model, main = "Variable Importance for Detecting Wilt")
rf_predictions <- predict(rf_model, newdata = test_data)
confusionMatrix(rf_predictions, test_data$class, positive = "Wilt")


print("--- Q8: Logistic Regression for Red/Green Interaction ---")
train_data_original <- wilt_data %>% filter(source == "train")
interaction_model <- glm(class ~ Mean_Red * Mean_Green, data = train_data_original, family = "binomial")
summary(interaction_model)

print("--- Q6: Decision Tree Thresholds ---")
tree_model <- rpart(class ~ ., data = balanced_train_data, method = "class")

rpart.plot(tree_model,
           main = "Decision Tree: Mathematical Fingerprint of Wilt",
           type = 4,
           extra = 104,
           box.palette = c("lightgreen", "tomato"))

print("--- Q7: Analyzing False Negatives ---")
test_analysis <- test_data
test_analysis$Predicted <- rf_predictions

false_negatives <- test_analysis %>% filter(class == "Wilt" & Predicted == "Healthy")

print("--- Q5: Minimal Variable Model (NIR & Green Only) ---")
set.seed(123)
rf_minimal <- randomForest(class ~ Mean_NIR + Mean_Green,
                           data = balanced_train_data,
                           ntree = 500)

minimal_predictions <- predict(rf_minimal, newdata = test_data)

confusionMatrix(minimal_predictions, test_data$class, positive = "Wilt")
