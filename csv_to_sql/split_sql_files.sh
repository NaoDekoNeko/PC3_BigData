#!/bin/bash

echo "✂️ Dividiendo archivos SQL grandes..."

# Función para dividir archivos SQL
split_sql_file() {
    local file=$1
    local lines_per_file=$2
    local prefix=$3
    
    if [ -f "$file" ]; then
        echo "📄 Dividiendo $file..."
        
        # Extraer el CREATE TABLE
        head -20 "$file" > "${prefix}_schema.sql"
        
        # Dividir los INSERT statements
        tail -n +21 "$file" | split -l $lines_per_file - "${prefix}_part_"
        
        # Agregar extensión .sql a las partes
        for part in "${prefix}_part_"*; do
            if [ -f "$part" ]; then
                mv "$part" "${part}.sql"
                echo "✅ Creado: ${part}.sql"
            fi
        done
        
        echo "📊 $file dividido en partes de $lines_per_file líneas cada una"
    else
        echo "⚠️ Archivo $file no encontrado"
    fi
}

# Dividir archivos si existen
split_sql_file "csv_to_sql/dataset_vf.sql" 10000 "csv_to_sql/dataset_vf"
split_sql_file "csv_to_sql/arbitrios_clean.sql" 10000 "csv_to_sql/arbitrios_clean"

echo "✅ División completada"
echo "💡 Ahora puedes subir las partes por separado"