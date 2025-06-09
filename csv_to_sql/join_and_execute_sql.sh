#!/bin/bash

echo "🔗 Script para unir y ejecutar archivos SQL divididos"

# Configuración de base de datos
DB_USER="postgres"
DB_NAME="postgres"
DB_HOST="localhost"
DB_PORT="5432"

# Función para mostrar ayuda
show_help() {
    echo "Uso: $0 [opciones] PREFIX"
    echo ""
    echo "Opciones:"
    echo "  -u, --user USER      Usuario de PostgreSQL (default: postgres)"
    echo "  -d, --database DB    Base de datos (default: postgres)"
    echo "  -h, --host HOST      Host (default: localhost)"
    echo "  -p, --port PORT      Puerto (default: 5432)"
    echo "  -j, --join-only      Solo unir archivos, no ejecutar"
    echo "  -e, --execute-only   Solo ejecutar (asume que ya están unidos)"
    echo "  -c, --clean         Limpiar archivos temporales después"
    echo "  --help              Mostrar esta ayuda"
    echo ""
    echo "Ejemplos:"
    echo "  $0 dataset_vf                    # Unir y ejecutar dataset_vf"
    echo "  $0 -j arbitrios_clean           # Solo unir arbitrios_clean"
    echo "  $0 -u myuser -d mydb dataset_vf  # Con credenciales personalizadas"
}

# Función para unir archivos SQL
join_sql_files() {
    local prefix=$1
    local output_file="${prefix}_complete.sql"
    
    echo "🔗 Uniendo archivos SQL para: $prefix"
    
    # Verificar si existe el schema
    if [ ! -f "${prefix}_schema.sql" ]; then
        echo "❌ Error: No se encuentra ${prefix}_schema.sql"
        return 1
    fi
    
    # Verificar si existen partes
    if ! ls "${prefix}_part_"*.sql 1> /dev/null 2>&1; then
        echo "❌ Error: No se encuentran archivos ${prefix}_part_*.sql"
        return 1
    fi
    
    # Crear archivo completo
    echo "📄 Creando archivo completo: $output_file"
    
    # Agregar schema
    cat "${prefix}_schema.sql" > "$output_file"
    echo "" >> "$output_file"
    
    # Agregar todas las partes en orden
    for part in $(ls "${prefix}_part_"*.sql | sort -V); do
        echo "📎 Agregando: $part"
        cat "$part" >> "$output_file"
    done
    
    echo "✅ Archivo unido creado: $output_file"
    
    # Mostrar estadísticas
    local total_lines=$(wc -l < "$output_file")
    local file_size=$(du -h "$output_file" | cut -f1)
    echo "📊 Estadísticas: $total_lines líneas, $file_size"
    
    return 0
}

# Función para ejecutar SQL en PostgreSQL
execute_sql() {
    local sql_file=$1
    
    echo "🚀 Ejecutando SQL en PostgreSQL..."
    echo "📋 Archivo: $sql_file"
    echo "🔧 Configuración: $DB_USER@$DB_HOST:$DB_PORT/$DB_NAME"
    
    # Verificar si el archivo existe
    if [ ! -f "$sql_file" ]; then
        echo "❌ Error: Archivo $sql_file no encontrado"
        return 1
    fi
    
    # Verificar conexión a PostgreSQL
    echo "🔍 Verificando conexión a PostgreSQL..."
    if ! psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" >/dev/null 2>&1; then
        echo "❌ Error: No se puede conectar a PostgreSQL"
        echo "💡 Verifica que PostgreSQL esté ejecutándose y las credenciales sean correctas"
        return 1
    fi
    
    # Ejecutar el SQL
    echo "⚡ Ejecutando SQL..."
    start_time=$(date +%s)
    
    if psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -f "$sql_file"; then
        end_time=$(date +%s)
        duration=$((end_time - start_time))
        echo "✅ SQL ejecutado exitosamente en ${duration} segundos"
        
        # Mostrar información de la tabla creada
        table_name=$(grep -i "CREATE TABLE" "$sql_file" | head -1 | sed 's/.*CREATE TABLE \([^ ]*\).*/\1/' | tr -d '();')
        if [ ! -z "$table_name" ]; then
            echo "📊 Información de la tabla $table_name:"
            psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c "SELECT COUNT(*) as total_registros FROM $table_name;"
        fi
        
        return 0
    else
        echo "❌ Error ejecutando SQL"
        return 1
    fi
}

# Función para limpiar archivos temporales
cleanup_files() {
    local prefix=$1
    
    echo "🧹 Limpiando archivos temporales..."
    
    # Preguntar confirmación
    read -p "¿Eliminar archivos divididos de $prefix? (y/N): " confirm
    if [[ $confirm =~ ^[Yy]$ ]]; then
        rm -f "${prefix}_part_"*.sql
        rm -f "${prefix}_schema.sql"
        echo "✅ Archivos temporales eliminados"
    else
        echo "📁 Archivos temporales conservados"
    fi
}

# Función principal
main() {
    local join_only=false
    local execute_only=false
    local clean_after=false
    local prefix=""
    
    # Procesar argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--user)
                DB_USER="$2"
                shift 2
                ;;
            -d|--database)
                DB_NAME="$2"
                shift 2
                ;;
            -h|--host)
                DB_HOST="$2"
                shift 2
                ;;
            -p|--port)
                DB_PORT="$2"
                shift 2
                ;;
            -j|--join-only)
                join_only=true
                shift
                ;;
            -e|--execute-only)
                execute_only=true
                shift
                ;;
            -c|--clean)
                clean_after=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            -*)
                echo "❌ Opción desconocida: $1"
                show_help
                exit 1
                ;;
            *)
                if [ -z "$prefix" ]; then
                    prefix="$1"
                else
                    echo "❌ Múltiples prefijos no soportados"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Verificar que se proporcionó un prefijo
    if [ -z "$prefix" ]; then
        echo "❌ Error: Debe proporcionar un prefijo"
        show_help
        exit 1
    fi
    
    # Ejecutar según las opciones
    if [ "$execute_only" = true ]; then
        # Solo ejecutar
        sql_file="${prefix}_complete.sql"
        if execute_sql "$sql_file"; then
            echo "🎉 Ejecución completada exitosamente"
        else
            exit 1
        fi
    elif [ "$join_only" = true ]; then
        # Solo unir
        if join_sql_files "$prefix"; then
            echo "🎉 Archivos unidos exitosamente"
        else
            exit 1
        fi
    else
        # Unir y ejecutar
        if join_sql_files "$prefix"; then
            sql_file="${prefix}_complete.sql"
            if execute_sql "$sql_file"; then
                echo "🎉 Proceso completado exitosamente"
                
                # Limpiar si se solicitó
                if [ "$clean_after" = true ]; then
                    cleanup_files "$prefix"
                fi
            else
                exit 1
            fi
        else
            exit 1
        fi
    fi
}

# Verificar dependencias
if ! command -v psql &> /dev/null; then
    echo "❌ Error: psql no está instalado"
    echo "💡 Instala PostgreSQL client"
    exit 1
fi

# Ejecutar función principal
main "$@"