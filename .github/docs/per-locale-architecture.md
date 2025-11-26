# Per-Locale Job Splitting Architecture

## Executive Summary

This document proposes refactoring the screenshot generation workflow to split jobs by locale, enabling parallel execution and reducing total pipeline runtime from 60-90 minutes to 25-35 minutes. This represents a 50% reduction in execution time while improving fault isolation and retry granularity.

## Current State

### Architecture
- **Single job per device type**: `screenshots-iphone` and `screenshots-ipad`
- **Sequential locale processing**: Each job processes all locales (en, fi) sequentially
- **Runtime**: 60-90 minutes per job (device type)
- **Total pipeline time**: 60-90 minutes (parallel device jobs)

### Pain Points
1. **Long execution times**: Single failures require re-running all locales
2. **Poor isolation**: Locale-specific issues affect entire job
3. **Limited parallelization**: Only device-level parallelism utilized
4. **Difficult debugging**: Mixed logs from multiple locales

### Current Job Flow
```
build-ios-test-products (15-20 min)
    |
    +-- screenshots-iphone (60-90 min)
    |   |-- Process locale: en (30-45 min)
    |   +-- Process locale: fi (30-45 min)
    |
    +-- screenshots-ipad (60-90 min)
        |-- Process locale: en (30-45 min)
        +-- Process locale: fi (30-45 min)
```

## Proposed State

### Architecture
- **Per-locale jobs**: Split by both device and locale
- **Parallel execution**: All device-locale combinations run simultaneously
- **Artifact merging**: Dedicated job to combine outputs
- **Runtime**: 25-35 minutes per device-locale job, 30-40 minutes total

### Proposed Job Flow
```
build-ios-test-products (15-20 min)
    |
    +-- screenshots-iphone-en (25-35 min) --+
    |                                        |
    +-- screenshots-iphone-fi (25-35 min) --+
    |                                        |
    +-- screenshots-ipad-en (25-35 min) ----+-- merge-screenshots (5-10 min)
    |                                        |
    +-- screenshots-ipad-fi (25-35 min) ----+
```

## Detailed Job Structure

### 1. build-ios-test-products
**Purpose**: Shared build artifacts for all screenshot jobs

**Responsibilities**:
- Build test products once
- Upload artifacts for downstream jobs
- Validate build success

**Duration**: 15-20 minutes
**Changes**: None (already exists)

### 2. screenshots-{device}-{locale}
**Purpose**: Generate screenshots for specific device-locale combination

**Jobs**:
- `screenshots-iphone-en`
- `screenshots-iphone-fi`
- `screenshots-ipad-en`
- `screenshots-ipad-fi`

**Responsibilities**:
- Download shared build artifacts
- Boot simulator for specific device
- Run UI tests for single locale
- Generate and optimize screenshots
- Upload locale-specific artifacts

**Duration**: 25-35 minutes per job
**Parallelism**: All 4 jobs run simultaneously

**Matrix Configuration**:
```yaml
strategy:
  matrix:
    device: [iphone, ipad]
    locale: [en, fi]
```

### 3. merge-screenshots
**Purpose**: Combine all locale-specific screenshots into final artifacts

**Responsibilities**:
- Download all device-locale artifacts
- Validate completeness (all expected screenshots present)
- Merge into device-specific artifact bundles
- Upload final artifacts for distribution
- Generate validation report

**Duration**: 5-10 minutes
**Dependencies**: All screenshots-{device}-{locale} jobs

## Benefits

### Performance
- **50% faster total runtime**: 60-90 min → 30-40 min
- **Better parallelization**: 4-way parallelism instead of 2-way
- **Efficient resource usage**: GitHub Actions concurrent job limits

### Reliability
- **Fault isolation**: Locale-specific failures don't block other locales
- **Granular retries**: Re-run only failed device-locale combinations
- **Clearer logs**: Single locale per job simplifies debugging

### Maintainability
- **Modular structure**: Each job has single responsibility
- **Easier testing**: Test individual device-locale combinations
- **Better monitoring**: Track success rates per device-locale

## Risks and Mitigations

### 1. Artifact Storage Overhead
**Risk**: More artifacts increase storage costs and transfer time

**Mitigation**:
- Aggressive artifact cleanup (1-7 day retention)
- Compression of screenshot artifacts
- Selective artifact uploads (only screenshots, not full test products)

### 2. Increased Complexity
**Risk**: More jobs increase workflow complexity

**Mitigation**:
- Use matrix strategy to reduce duplication
- Shared composite actions for common steps
- Clear documentation and naming conventions

### 3. GitHub Actions Job Limits
**Risk**: Free tier has concurrent job limits

**Mitigation**:
- Current limit (20 jobs) sufficient for our needs
- Monitor queue times in GitHub Actions metrics
- Consider GitHub Teams if scaling further

### 4. Merge Job Failure
**Risk**: Merge job could fail after all screenshots succeed

**Mitigation**:
- Keep merge logic simple and reliable
- Implement validation checks before merge
- Support manual merge if needed

## Implementation Plan

### Phase 1: Preparation (PR #1) - ✅ COMPLETED
**Duration**: 1-2 days

**Tasks**:
1. ✅ Create locale-specific Fastlane lanes (`screenshots_iphone_locale`, `screenshots_ipad_locale`)
2. ✅ Add artifact validation logic
3. ✅ Update documentation
4. ✅ Backward-compatible changes (old lanes still work)

**Success Criteria**: ✅ New lanes work with locale parameter

### Phase 2: Split iPhone Jobs (PR #2) - ✅ COMPLETED
**Duration**: 2-3 days

**Tasks**:
1. ✅ Split screenshots-iphone into matrix jobs (en-US, fi)
2. ✅ Add merge-screenshots job to combine artifacts
3. ✅ Run iPhone locales in parallel
4. Monitor stability over 5-10 runs

**Success Criteria**: iPhone locale jobs execute in parallel

### Phase 3: Split iPad Jobs (PR #3) - ✅ COMPLETED
**Duration**: 2-3 days

**Tasks**:
1. ✅ Split screenshots-ipad into matrix jobs (en-US, fi)
2. ✅ Update merge job to handle all 4 locale artifacts
3. ✅ Full 5-way parallel execution (iPhone×2, iPad×2, Watch)
4. Monitor stability

**Success Criteria**: All locale jobs succeed, <35 min total runtime

### Rollback Plan
- Revert to previous commit if success rate drops below 80%
- Old `screenshots_iphone` and `screenshots_ipad` lanes still work
- Can manually run `bundle exec fastlane ios screenshots_iphone` locally

## Success Metrics

### Primary Metrics
- **Total runtime**: <35 minutes (90th percentile)
- **Success rate**: >90% for per-locale jobs
- **Retry efficiency**: Individual locale retries complete in <10 minutes

### Secondary Metrics
- **Artifact size**: <500 MB total per run
- **Queue time**: <5 minutes wait for job start
- **Debug time**: 30% reduction in time to identify locale issues

### Monitoring
- GitHub Actions built-in metrics
- Custom success rate tracking in README
- Alert on 3 consecutive failures for any device-locale combination

## Future Enhancements

### Additional Locales
With this architecture, adding new locales is straightforward:
1. Add locale to matrix configuration
2. No changes to individual job logic
3. Automatic parallelization

### Device-Specific Optimizations
Per-device jobs enable device-specific configurations:
- Different timeouts for iPad vs iPhone
- Device-specific simulator settings
- Targeted retry strategies

### Canary Deployments
Test workflow changes on single locale before full rollout:
1. Deploy change to screenshots-iphone-en only
2. Monitor for 24 hours
3. Roll out to remaining jobs if stable

## Conclusion

Per-locale job splitting represents a significant improvement in screenshot pipeline efficiency and reliability. The phased implementation plan minimizes risk while delivering measurable benefits. With proper monitoring and rollback procedures, this architecture will support faster iteration and better developer experience.

## References

- Workflow: `.github/workflows/prepare-appstore.yml`
- Fastfile lanes: `fastlane/Fastfile` (screenshots_iphone_locale, screenshots_ipad_locale)
- Validation script: `.github/scripts/validate-screenshots.sh`
- Related audit: `.github/docs/screenshot-pipeline-audit.md`
