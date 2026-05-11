import React, { useState, useMemo } from "react";
import Icon from "./Icon";

export type RecordRow = Record<string, any>;

interface Column {
  id: string;
  header: string;
  width?: string;
}

interface SimpleTableProps {
  columns: Column[];
  rows: RecordRow[];
  rowKey?: (row: RecordRow, idx: number) => string;
  onRowClick?: (row: RecordRow, idx: number) => void;
  selectedRows?: Set<string>;
  onSelectionChange?: (selected: Set<string>) => void;
}

export default function SimpleTable({
  columns,
  rows,
  rowKey = (_, idx) => String(idx),
  onRowClick,
  selectedRows = new Set(),
  onSelectionChange,
}: SimpleTableProps) {
  const [sortColumn, setSortColumn] = useState<string | null>(null);
  const [sortDir, setSortDir] = useState<"asc" | "desc">("asc");

  const sortedRows = useMemo(() => {
    if (!sortColumn) return rows;

    return [...rows].sort((a, b) => {
      const aVal = a[sortColumn];
      const bVal = b[sortColumn];

      if (aVal == null && bVal == null) return 0;
      if (aVal == null) return sortDir === "asc" ? 1 : -1;
      if (bVal == null) return sortDir === "asc" ? -1 : 1;

      if (typeof aVal === "string" && typeof bVal === "string") {
        const cmp = aVal.localeCompare(bVal);
        return sortDir === "asc" ? cmp : -cmp;
      }

      if (typeof aVal === "number" && typeof bVal === "number") {
        return sortDir === "asc" ? aVal - bVal : bVal - aVal;
      }

      const aStr = String(aVal);
      const bStr = String(bVal);
      const cmp = aStr.localeCompare(bStr);
      return sortDir === "asc" ? cmp : -cmp;
    });
  }, [rows, sortColumn, sortDir]);

  const handleSort = (colId: string) => {
    if (sortColumn === colId) {
      setSortDir(sortDir === "asc" ? "desc" : "asc");
    } else {
      setSortColumn(colId);
      setSortDir("asc");
    }
  };

  const handleRowSelect = (rowKey: string) => {
    const newSelected = new Set(selectedRows);
    if (newSelected.has(rowKey)) {
      newSelected.delete(rowKey);
    } else {
      newSelected.add(rowKey);
    }
    onSelectionChange?.(newSelected);
  };

  const handleSelectAll = () => {
    if (selectedRows.size === rows.length) {
      onSelectionChange?.(new Set());
    } else {
      const allKeys = new Set(rows.map((_, idx) => rowKey(_, idx)));
      onSelectionChange?.(allKeys);
    }
  };

  return (
    <div className="simple-table-wrapper">
      <table className="simple-table">
        <thead>
          <tr>
            {onSelectionChange && (
              <th style={{ width: "40px" }}>
                <input
                  type="checkbox"
                  checked={selectedRows.size === rows.length && rows.length > 0}
                  onChange={handleSelectAll}
                />
              </th>
            )}
            {columns.map((col) => (
              <th key={col.id} style={{ width: col.width }} onClick={() => handleSort(col.id)}>
                <div className="table-header">
                  <span>{col.header}</span>
                  {sortColumn === col.id && (
                    <Icon name={sortDir === "asc" ? "caret-down" : "caret-up"} size={14} />
                  )}
                </div>
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {sortedRows.map((row, idx) => {
            const key = rowKey(row, idx);
            const isSelected = selectedRows.has(key);
            return (
              <tr
                key={key}
                className={isSelected ? "table-row--selected" : ""}
                onClick={() => onRowClick?.(row, idx)}
              >
                {onSelectionChange && (
                  <td>
                    <input
                      type="checkbox"
                      checked={isSelected}
                      onChange={() => handleRowSelect(key)}
                      onClick={(e) => e.stopPropagation()}
                    />
                  </td>
                )}
                {columns.map((col) => (
                  <td key={`${key}_${col.id}`}>{String(row[col.id] ?? "")}</td>
                ))}
              </tr>
            );
          })}
        </tbody>
      </table>
      {rows.length === 0 && (
        <div className="table-empty">Žádné záznamy</div>
      )}
    </div>
  );
}
