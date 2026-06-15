<?php extend('layouts/backend_layout'); ?>

<?php section('content'); ?>

<div class="container backend-page py-3" id="companies-page">
    <div class="row" id="companies">
        <div id="filter-companies" class="filter-records col col-12 mb-4">
            <button id="add-company" class="btn btn-primary add-record-btn mb-4">
                <i class="fas fa-plus-square me-2"></i>
                <?= lang('add') ?>
            </button>

            <form class="mb-4">
                <div class="input-group">
                    <input type="text" class="key form-control" aria-label="keyword">

                    <button class="filter btn btn-outline-secondary" type="submit"
                            data-tippy-content="<?= lang('filter') ?>">
                        <i class="fas fa-search"></i>
                    </button>
                </div>
            </form>

            <h4 class="mb-3 fw-light">
                <?= lang('companies') ?>
            </h4>

            <div class="results overflow-auto" style="max-height: 650px;">
                <!-- JS -->
            </div>
        </div>

        <div class="record-details column col-12 mb-4">
            <div class="btn-toolbar mb-4">
                <div class="add-edit-delete-group btn-group">
                    <button id="edit-company" class="btn btn-outline-secondary" disabled="disabled">
                        <i class="fas fa-edit me-2"></i>
                        <?= lang('edit') ?>
                    </button>
                </div>

                <div class="save-cancel-group" style="display:none;">
                    <button id="save-company" class="btn btn-primary">
                        <i class="fas fa-check-square me-2"></i>
                        <?= lang('save') ?>
                    </button>
                    <button id="cancel-company" class="btn btn-outline-secondary">
                        <?= lang('cancel') ?>
                    </button>
                    <button id="delete-company" class="btn btn-outline-danger ms-2">
                        <i class="fas fa-trash-alt me-2"></i>
                        <?= lang('delete') ?>
                    </button>
                </div>
            </div>

            <h4 class="mb-3 fw-light">
                <?= lang('details') ?>
            </h4>

            <div class="form-message alert" style="display:none;"></div>

            <input type="hidden" id="id">

            <div class="mb-3">
                <label class="form-label" for="name">
                    <?= lang('name') ?>
                    <span class="text-danger" hidden>*</span>
                </label>
                <input id="name" class="form-control required" maxlength="256" disabled>
            </div>

            <div class="mb-3">
                <label class="form-label" for="slug">
                    <?= lang('slug') ?>
                </label>
                <input id="slug" class="form-control" maxlength="256" disabled
                       placeholder="<?= lang('auto_generated') ?>">
                <div class="form-text text-muted">
                    <small><?= lang('slug_hint') ?></small>
                </div>
            </div>

            <div class="mb-3">
                <label class="form-label" for="email">
                    <?= lang('email') ?>
                </label>
                <input id="email" type="email" class="form-control" maxlength="512" disabled>
            </div>

            <div class="mb-3">
                <label class="form-label" for="phone-number">
                    <?= lang('phone_number') ?>
                </label>
                <input id="phone-number" class="form-control" maxlength="128" disabled>
            </div>

            <div class="mb-3">
                <label class="form-label" for="address">
                    <?= lang('address') ?>
                </label>
                <input id="address" class="form-control" maxlength="256" disabled>
            </div>

            <div class="row">
                <div class="col-md-6 mb-3">
                    <label class="form-label" for="city">
                        <?= lang('city') ?>
                    </label>
                    <input id="city" class="form-control" maxlength="256" disabled>
                </div>
                <div class="col-md-3 mb-3">
                    <label class="form-label" for="state">
                        <?= lang('state') ?>
                    </label>
                    <input id="state" class="form-control" maxlength="128" disabled>
                </div>
                <div class="col-md-3 mb-3">
                    <label class="form-label" for="zip-code">
                        <?= lang('zip_code') ?>
                    </label>
                    <input id="zip-code" class="form-control" maxlength="64" disabled>
                </div>
            </div>

            <div class="mb-3">
                <label class="form-label" for="timezone">
                    <?= lang('timezone') ?>
                </label>
                <select id="timezone" class="form-select" disabled>
                    <option value=""><?= lang('none') ?></option>
                    <?php foreach (vars('timezones') as $value => $label): ?>
                        <option value="<?= e($value) ?>"><?= e($label) ?></option>
                    <?php endforeach; ?>
                </select>
            </div>

            <div class="mb-3">
                <label class="form-label" for="language">
                    <?= lang('language') ?>
                </label>
                <input id="language" class="form-control" maxlength="256" disabled>
            </div>

            <div class="mb-3">
                <label class="form-label" for="description">
                    <?= lang('description') ?>
                </label>
                <textarea id="description" rows="3" class="form-control" disabled></textarea>
            </div>

            <div class="mb-3">
                <label class="form-label" for="notes">
                    <?= lang('notes') ?>
                </label>
                <textarea id="notes" rows="3" class="form-control" disabled></textarea>
            </div>

            <div class="border rounded mb-3 p-3">
                <div class="form-check form-switch">
                    <input class="form-check-input" type="checkbox" id="is-private" disabled>
                    <label class="form-check-label" for="is-private">
                        <?= lang('hide_from_public') ?>
                    </label>
                </div>
            </div>

            <div class="d-flex justify-content-between align-items-center mb-3">
                <label class="form-label mb-0">
                    <?= lang('providers') ?>
                </label>
                <div class="btn-group btn-group-sm">
                    <button type="button" id="select-all-providers" class="btn btn-outline-secondary" disabled>
                        <?= lang('select_all') ?>
                    </button>
                    <button type="button" id="select-none-providers" class="btn btn-outline-secondary" disabled>
                        <?= lang('select_none') ?>
                    </button>
                </div>
            </div>

            <div id="company-providers" class="card card-body border mb-3">
                <?php foreach (vars('providers') as $provider): ?>
                    <div class="d-flex align-items-center justify-content-between py-1">
                        <div class="form-check mb-0">
                            <input class="form-check-input" type="checkbox"
                                   id="provider-<?= $provider['id'] ?>"
                                   data-id="<?= $provider['id'] ?>" disabled>
                            <label class="form-check-label" for="provider-<?= $provider['id'] ?>">
                                <?= e($provider['first_name'] . ' ' . $provider['last_name']) ?>
                            </label>
                        </div>
                        <button type="button"
                                class="btn btn-sm btn-outline-secondary set-provider-working-plan d-none"
                                data-provider-id="<?= $provider['id'] ?>"
                                data-provider-name="<?= e($provider['first_name'] . ' ' . $provider['last_name']) ?>"
                                title="<?= lang('working_plan') ?>">
                            <i class="fas fa-clock"></i>
                        </button>
                    </div>
                <?php endforeach; ?>
            </div>

            <div class="mt-4 mb-2">
                <label class="form-label mb-2 fw-semibold">
                    <?= lang('secretaries') ?>
                </label>
                <div id="company-secretaries" class="card card-body border bg-light py-2">
                    <span class="text-muted small" id="company-secretaries-empty"><?= lang('no_records_found') ?></span>
                </div>
            </div>

        </div>
    </div>
</div>

<!-- Modal: Provider Working Plan per Company -->
<div class="modal fade" id="provider-working-plan-modal" tabindex="-1" aria-hidden="true">
    <div class="modal-dialog modal-lg">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">
                    <i class="fas fa-clock me-2"></i>
                    <span id="modal-provider-name"></span>
                    &mdash; <?= lang('working_plan') ?>
                </h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="<?= lang('cancel') ?>"></button>
            </div>
            <div class="modal-body">
                <p class="text-muted small mb-3"><?= lang('working_plan_company_hint') ?></p>
                <div class="alert alert-danger conflict-alert mb-3" style="display:none;"></div>
                <input type="hidden" id="modal-company-id">
                <input type="hidden" id="modal-provider-id">

                <div class="table-responsive">
                    <table class="table table-bordered align-middle" id="company-working-plan-table">
                        <thead class="table-light">
                        <tr>
                            <th><?= lang('day') ?></th>
                            <th><?= lang('working') ?></th>
                            <th><?= lang('start') ?></th>
                            <th><?= lang('end') ?></th>
                            <th class="text-warning"><?= lang('occupied_by') ?></th>
                        </tr>
                        </thead>
                        <tbody>
                        <?php
                        $days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
                        foreach ($days as $day):
                        ?>
                        <tr data-day="<?= $day ?>">
                            <td class="fw-medium"><?= lang($day) ?></td>
                            <td class="text-center">
                                <input type="checkbox" class="form-check-input day-active" id="cwp-<?= $day ?>">
                            </td>
                            <td>
                                <input type="time" class="form-control form-control-sm day-start"
                                       id="cwp-<?= $day ?>-start" value="09:00" disabled>
                            </td>
                            <td>
                                <input type="time" class="form-control form-control-sm day-end"
                                       id="cwp-<?= $day ?>-end" value="18:00" disabled>
                            </td>
                            <td class="day-conflict small text-muted"></td>
                        </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-outline-secondary" data-bs-dismiss="modal">
                    <?= lang('cancel') ?>
                </button>
                <button type="button" class="btn btn-primary" id="save-provider-working-plan">
                    <i class="fas fa-check-square me-2"></i>
                    <?= lang('save') ?>
                </button>
            </div>
        </div>
    </div>
</div>

<?php end_section('content'); ?>

<?php section('scripts'); ?>

<script src="<?= asset_url('assets/js/http/companies_http_client.js') ?>"></script>
<script src="<?= asset_url('assets/js/pages/companies.js') ?>"></script>

<?php end_section('scripts'); ?>
