import $ivy.`org.apache.spark::spark-sql:3.5.6`
import $ivy.`org.apache.spark::spark-core:3.5.6`
import org.apache.spark.sql.SparkSession

val spark = SparkSession.builder()
  .appName("Notebook")
  .master("local[*]")
  .getOrCreate()

import spark.implicits._