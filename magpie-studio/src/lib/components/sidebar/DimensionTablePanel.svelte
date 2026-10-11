<script lang="ts">
  import { measurementsStore, type MeasurementItem, type DimensionProvenance } from '$lib/stores/measurements';
  import { projectSettings, formatLength } from '$lib/stores/settings';

  let measurements = $derived($measurementsStore);
  let settings = $derived($projectSettings);

  let filterKind = $state<string>('all');
  let filterCritical = $state<boolean>(false);

  let filteredDimensions = $derived.by(() => {
    if (!measurements) return [];
    return measurements.dimensions.filter(d => {
      if (filterCritical && !d.critical) return false;
      if (filterKind !== 'all' && d.kind !== filterKind) return false;
      return true;
    });
  });

  function formatMm(valMm: number): string {
    // formatLength expects cm; valMm / 10 converts mm to cm
    return formatLength(valMm / 10, settings.units);
  }
</script>

<div class="dimension-table-panel" data-testid="dimension-table-panel">
  {#if !measurements}
    <div class="empty-state">
      <div class="empty-icon">📏</div>
      <h3>No Measurements Available</h3>
      <p>Load a .magpie package or measurements.json sidecar to inspect certified dimensions and calibration data.</p>
    </div>
  {:else}
    <!-- Validation Summary Card -->
    <div class="summary-card" class:pass={measurements.validation.gateResult === 'pass'} class:fail={measurements.validation.gateResult !== 'pass'}>
      <div class="summary-header">
        <span class="gate-badge" class:pass={measurements.validation.gateResult === 'pass'}>
          {measurements.validation.gateResult.toUpperCase()}
        </span>
        <span class="pass-rate">
          {Math.round(measurements.validation.passRate * 100)}% Passing
        </span>
      </div>
      <div class="summary-stats">
        <div class="stat-item">
          <span class="stat-label">Critical Dimensions</span>
          <span class="stat-value">{measurements.validation.criticalWithinTolerance} / {measurements.validation.criticalCount}</span>
        </div>
        <div class="stat-item">
          <span class="stat-label">Total Measured</span>
          <span class="stat-value">{measurements.dimensions.length}</span>
        </div>
        {#if measurements.validation.photosCaptured > 0}
          <div class="stat-item">
            <span class="stat-label">Photos Captured</span>
            <span class="stat-value">{measurements.validation.photosCaptured}</span>
          </div>
        {/if}
      </div>
    </div>

    <!-- Capture Metadata & Calibration Info -->
    <div class="info-section">
      <details>
        <summary><strong>Metadata & Calibration Details</strong></summary>
        <div class="meta-grid">
          <div><span class="label">Site:</span> {measurements.siteId}</div>
          <div><span class="label">Worker:</span> {measurements.workerName}</div>
          <div><span class="label">Captured:</span> {new Date(measurements.capturedAt).toLocaleString()}</div>
          <div><span class="label">Device:</span> {measurements.deviceModel} ({measurements.appVersion})</div>
          {#if measurements.calibration}
            <div class="calibration-info">
              <span class="label">Calibration Bias:</span>
              <code>×{measurements.calibration.biasFactor.toFixed(4)}</code> ({measurements.calibration.referenceDescription})
            </div>
          {/if}
        </div>
      </details>
    </div>

    <!-- Filter Controls -->
    <div class="filter-bar">
      <select bind:value={filterKind} aria-label="Filter dimension kind">
        <option value="all">All Kinds</option>
        <option value="wall">Walls</option>
        <option value="opening">Openings</option>
        <option value="ceiling">Ceilings</option>
        <option value="gap">Cabinet Gaps</option>
      </select>
      <label class="critical-toggle">
        <input type="checkbox" bind:checked={filterCritical} />
        Critical Only
      </label>
    </div>

    <!-- Dimension Table -->
    <div class="table-container">
      <table class="measurements-table" role="grid">
        <thead>
          <tr>
            <th>Name / Kind</th>
            <th>Governing</th>
            <th>Scanned</th>
            <th>Dev</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {#each filteredDimensions as dim (dim.id)}
            <tr class="dim-row" class:critical-row={dim.critical}>
              <td class="dim-label">
                <div class="name-container">
                  <strong>{dim.label}</strong>
                  {#if dim.critical}
                    <span class="critical-badge" title="Critical Kitchen Dimension">★ CRITICAL</span>
                  {/if}
                </div>
                <div class="kind-tag">{dim.kind}</div>
              </td>
              <!-- Tape vs Scanned distinction: Tape is bold, strong, dark; Scanned is muted with approx marker -->
              <td class="dim-value" data-provenance={dim.provenance}>
                {#if dim.provenance === 'tape'}
                  <span class="val-tape" title="Certified tape measurement">
                    <strong>{formatMm(dim.valueMm)}</strong>
                    <span class="prov-tag tape">TAPE</span>
                  </span>
                {:else if dim.provenance === 'calibrated'}
                  <span class="val-calibrated" title="Bias calibrated">
                    {formatMm(dim.valueMm)}
                    <span class="prov-tag cal">CAL</span>
                  </span>
                {:else if dim.provenance === 'derived'}
                  <span class="val-derived" title="Derived calculation">
                    {formatMm(dim.valueMm)}
                    <span class="prov-tag dev">DER</span>
                  </span>
                {:else}
                  <span class="val-scanned" title="Uncertified LiDAR scan">
                    <span class="approx-marker">~</span>{formatMm(dim.valueMm)}
                    <span class="prov-tag scan">SCAN</span>
                  </span>
                {/if}
              </td>
              <td class="dim-scanned">
                <span class="approx-marker">~</span>{formatMm(dim.valueScannedMm)}
              </td>
              <td class="dim-dev">
                <span class="dev-num" class:dev-high={!dim.withinTolerance}>
                  {dim.deviationMm > 0 ? `±${dim.deviationMm}mm` : '0mm'}
                </span>
              </td>
              <td class="dim-status">
                {#if dim.withinTolerance}
                  <span class="status-badge ok" title="Within tolerance (≤{dim.toleranceMm}mm)">✓ OK</span>
                {:else}
                  <span class="status-badge fail" title="Exceeds tolerance (>{dim.toleranceMm}mm)">✗ HIGH</span>
                {/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>

    <!-- Kitchen Tags Section -->
    {#if measurements.kitchenTags && measurements.kitchenTags.length > 0}
      <div class="tags-section">
        <h4>Kitchen Run Tags</h4>
        <div class="tag-chips">
          {#each measurements.kitchenTags as tag (tag.id)}
            <span class="tag-chip" title={tag.description || tag.tag}>
              🏷️ {tag.tag}
            </span>
          {/each}
        </div>
      </div>
    {/if}
  {/if}
</div>

<style>
  .dimension-table-panel {
    display: flex;
    flex-direction: column;
    gap: 12px;
    padding: 12px;
    font-size: 13px;
    color: var(--text-color, #222);
    overflow-y: auto;
    height: 100%;
  }

  .empty-state {
    text-align: center;
    padding: 32px 16px;
    color: #666;
  }
  .empty-icon {
    font-size: 32px;
    margin-bottom: 8px;
  }

  .summary-card {
    border-radius: 8px;
    padding: 12px;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
  }
  .summary-card.pass {
    border-left: 4px solid #16a34a;
    background: #f0fdf4;
  }
  .summary-card.fail {
    border-left: 4px solid #dc2626;
    background: #fef2f2;
  }

  .summary-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
  }
  .gate-badge {
    padding: 2px 8px;
    border-radius: 4px;
    font-weight: 700;
    font-size: 11px;
    color: white;
    background: #dc2626;
  }
  .gate-badge.pass {
    background: #16a34a;
  }
  .pass-rate {
    font-weight: 600;
    font-size: 12px;
  }

  .summary-stats {
    display: flex;
    gap: 16px;
  }
  .stat-item {
    display: flex;
    flex-direction: column;
  }
  .stat-label {
    font-size: 10px;
    color: #64748b;
    text-transform: uppercase;
  }
  .stat-value {
    font-size: 14px;
    font-weight: 700;
  }

  .info-section details {
    font-size: 12px;
    color: #475569;
    background: #f1f5f9;
    padding: 6px 10px;
    border-radius: 6px;
  }
  .meta-grid {
    margin-top: 6px;
    display: grid;
    gap: 4px;
  }
  .meta-grid .label {
    font-weight: 600;
    color: #334155;
  }

  .filter-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 8px;
  }
  .filter-bar select {
    padding: 4px 8px;
    border-radius: 4px;
    border: 1px solid #cbd5e1;
    font-size: 12px;
  }
  .critical-toggle {
    font-size: 12px;
    cursor: pointer;
    display: flex;
    align-items: center;
    gap: 4px;
  }

  .table-container {
    overflow-x: auto;
    border: 1px solid #e2e8f0;
    border-radius: 6px;
  }
  .measurements-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 12px;
    text-align: left;
  }
  .measurements-table th {
    background: #f8fafc;
    padding: 6px 8px;
    border-bottom: 1px solid #cbd5e1;
    font-weight: 600;
    font-size: 11px;
    color: #475569;
  }
  .measurements-table td {
    padding: 6px 8px;
    border-bottom: 1px solid #f1f5f9;
  }

  .critical-row {
    background: #fffbeb;
  }
  .name-container {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .critical-badge {
    background: #f59e0b;
    color: #78350f;
    font-size: 9px;
    font-weight: 700;
    padding: 1px 4px;
    border-radius: 3px;
  }
  .kind-tag {
    font-size: 10px;
    color: #94a3b8;
  }

  /* Tape vs Scanned distinction per T-803 Rule: Tape is strong and dark; Scanned is muted with approx marker */
  .val-tape {
    color: #0f172a; /* Strong, dark */
    font-weight: 800;
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .val-scanned {
    color: #64748b; /* Muted */
    font-style: italic;
    display: inline-flex;
    align-items: center;
    gap: 2px;
  }
  .val-calibrated {
    color: #2563eb;
    font-weight: 600;
  }
  .val-derived {
    color: #7c3aed;
  }
  .approx-marker {
    font-weight: bold;
    color: #94a3b8;
  }

  .prov-tag {
    font-size: 8px;
    padding: 1px 3px;
    border-radius: 2px;
    font-weight: 700;
  }
  .prov-tag.tape {
    background: #1e293b;
    color: #f8fafc;
  }
  .prov-tag.scan {
    background: #e2e8f0;
    color: #475569;
  }
  .prov-tag.cal {
    background: #dbeafe;
    color: #1d4ed8;
  }
  .prov-tag.dev {
    background: #f3e8ff;
    color: #6b21a8;
  }

  .dim-scanned {
    color: #94a3b8;
  }
  .dim-dev .dev-high {
    color: #dc2626;
    font-weight: 700;
  }

  .status-badge {
    padding: 2px 5px;
    border-radius: 3px;
    font-size: 10px;
    font-weight: 700;
  }
  .status-badge.ok {
    background: #dcfce7;
    color: #15803d;
  }
  .status-badge.fail {
    background: #fee2e2;
    color: #b91c1c;
  }

  .tags-section {
    margin-top: 8px;
  }
  .tags-section h4 {
    margin: 0 0 4px 0;
    font-size: 11px;
    text-transform: uppercase;
    color: #64748b;
  }
  .tag-chips {
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }
  .tag-chip {
    background: #e2e8f0;
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 11px;
  }
</style>
