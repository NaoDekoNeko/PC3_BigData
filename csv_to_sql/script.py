import pandas as pd
import os
import sys
import argparse
from pathlib import Path

def csv_to_sql(csv_file_path, table_name=None, output_file=None, separator=','):
    """
    Convierte un archivo CSV a SQL INSERT statements
    
    Args:
        csv_file_path (str): Ruta al archivo CSV
        table_name (str): Nombre de la tabla (opcional, usa el nombre del archivo si no se especifica)
        output_file (str): Archivo de salida SQL (opcional, crea uno automáticamente si no se especifica)
        separator (str): Separador del CSV (por defecto ',')
    """
    
    try:
        # Leer el CSV con el separador especificado
        df = pd.read_csv(csv_file_path, sep=separator)
        
        # Obtener nombre de tabla si no se especifica
        if table_name is None:
            table_name = Path(csv_file_path).stem
        
        # Generar archivo de salida si no se especifica
        if output_file is None:
            output_file = Path(csv_file_path).with_suffix('.sql')
        
        # Obtener los headers/columnas
        columns = df.columns.tolist()
        
        # Crear el script SQL
        sql_content = []
        
        # Crear statement CREATE TABLE
        sql_content.append(f"-- Tabla generada desde {csv_file_path}")
        sql_content.append(f"-- Separador utilizado: '{separator}'")
        sql_content.append(f"CREATE TABLE {table_name} (")
        
        # Inferir tipos de datos básicos
        for i, col in enumerate(columns):
            # Limpiar nombre de columna
            clean_col = col.replace(' ', '_').replace('-', '_').replace('.', '_')
            
            # Inferir tipo de dato
            if pd.api.types.is_numeric_dtype(df[col]):
                if pd.api.types.is_integer_dtype(df[col]):
                    col_type = "INTEGER"
                else:
                    col_type = "DECIMAL(10,2)"
            else:
                col_type = "VARCHAR(255)"
            
            comma = "," if i < len(columns) - 1 else ""
            sql_content.append(f"    {clean_col} {col_type}{comma}")
        
        sql_content.append(");")
        sql_content.append("")
        
        # Crear INSERT statements
        sql_content.append(f"-- Datos insertados desde {csv_file_path}")
        
        for index, row in df.iterrows():
            values = []
            for col in columns:
                value = row[col]
                if pd.isna(value):
                    values.append("NULL")
                elif isinstance(value, str):
                    # Escapar comillas simples
                    escaped_value = value.replace("'", "''")
                    values.append(f"'{escaped_value}'")
                else:
                    values.append(str(value))
            
            clean_columns = [col.replace(' ', '_').replace('-', '_').replace('.', '_') for col in columns]
            columns_str = ", ".join(clean_columns)
            values_str = ", ".join(values)
            
            sql_content.append(f"INSERT INTO {table_name} ({columns_str}) VALUES ({values_str});")
        
        # Escribir archivo SQL
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(sql_content))
        
        print(f"✅ Archivo SQL generado exitosamente: {output_file}")
        print(f"📊 Registros procesados: {len(df)}")
        print(f"📋 Columnas: {len(columns)}")
        print(f"🔧 Separador utilizado: '{separator}'")
        
    except Exception as e:
        print(f"❌ Error procesando el archivo: {e}")

def detect_separator(csv_file_path):
    """
    Intenta detectar automáticamente el separador del CSV
    """
    common_separators = [',', ';', '\t', '|']
    
    with open(csv_file_path, 'r', encoding='utf-8') as f:
        first_line = f.readline()
    
    # Contar ocurrencias de cada separador
    separator_counts = {}
    for sep in common_separators:
        separator_counts[sep] = first_line.count(sep)
    
    # Devolver el separador más frecuente
    detected_sep = max(separator_counts, key=separator_counts.get)
    
    if separator_counts[detected_sep] > 0:
        return detected_sep
    else:
        return ','  # Default

def process_all_csvs_in_directory(directory_path=".", separator=None):
    """Procesa todos los archivos CSV en un directorio"""
    
    csv_files = list(Path(directory_path).glob("*.csv"))
    
    if not csv_files:
        print(f"❌ No se encontraron archivos CSV en {directory_path}")
        return
    
    print(f"📁 Procesando {len(csv_files)} archivos CSV...")
    
    for csv_file in csv_files:
        print(f"\n🔄 Procesando: {csv_file}")
        
        # Si no se especifica separador, detectarlo automáticamente
        if separator is None:
            file_separator = detect_separator(str(csv_file))
            print(f"🔍 Separador detectado: '{file_separator}'")
        else:
            file_separator = separator
            
        csv_to_sql(str(csv_file), separator=file_separator)

def main():
    """Función principal con argparse para manejar flags"""
    
    parser = argparse.ArgumentParser(
        description='Convierte archivos CSV a SQL INSERT statements',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Ejemplos de uso:
  python script.py -f datos.csv
  python script.py -f datos.csv -s ";"
  python script.py -f datos.csv -s ";" -t mi_tabla
  python script.py -f datos.csv -s ";" -t mi_tabla -o salida.sql
  python script.py --all
  python script.py --all -s ";"
  python script.py -f datos.csv --auto-detect
        """
    )
    
    # Grupo mutuamente exclusivo para archivo individual o todos los archivos
    file_group = parser.add_mutually_exclusive_group(required=True)
    file_group.add_argument(
        '-f', '--file',
        type=str,
        help='Archivo CSV a convertir'
    )
    file_group.add_argument(
        '--all',
        action='store_true',
        help='Procesar todos los archivos CSV en el directorio actual'
    )
    
    parser.add_argument(
        '-s', '--separator',
        type=str,
        default=None,
        help='Separador del CSV (por defecto: auto-detección). Ejemplos: "," ";" "\\t" "|"'
    )
    
    parser.add_argument(
        '-t', '--table',
        type=str,
        help='Nombre de la tabla SQL (por defecto: nombre del archivo)'
    )
    
    parser.add_argument(
        '-o', '--output',
        type=str,
        help='Archivo de salida SQL (por defecto: mismo nombre con extensión .sql)'
    )
    
    parser.add_argument(
        '--auto-detect',
        action='store_true',
        help='Forzar auto-detección del separador (útil para debugging)'
    )
    
    parser.add_argument(
        '-d', '--directory',
        type=str,
        default='.',
        help='Directorio para procesar archivos CSV (solo con --all, por defecto: directorio actual)'
    )
    
    args = parser.parse_args()
    
    # Determinar el separador
    if args.auto_detect and args.file:
        separator = detect_separator(args.file)
        print(f"🔍 Separador detectado automáticamente: '{separator}'")
    elif args.separator:
        separator = args.separator
        # Manejar casos especiales
        if separator.lower() == 'tab' or separator == '\\t':
            separator = '\t'
    else:
        separator = None  # Se detectará automáticamente
    
    # Procesar archivo individual o todos los archivos
    if args.file:
        if not os.path.exists(args.file):
            print(f"❌ El archivo {args.file} no existe")
            return
        
        # Si no se especificó separador, detectarlo automáticamente
        if separator is None:
            separator = detect_separator(args.file)
            print(f"🔍 Separador detectado automáticamente: '{separator}'")
        
        csv_to_sql(args.file, args.table, args.output, separator)
    
    elif args.all:
        process_all_csvs_in_directory(args.directory, separator)

if __name__ == "__main__":
    main()