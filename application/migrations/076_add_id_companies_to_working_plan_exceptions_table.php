<?php defined('BASEPATH') or exit('No direct script access allowed');

/* ----------------------------------------------------------------------------
 * Easy!Appointments - Online Appointment Scheduler
 *
 * @package     EasyAppointments
 * @author      A.Tselegidis <alextselegidis@gmail.com>
 * @copyright   Copyright (c) Alex Tselegidis
 * @license     https://opensource.org/licenses/GPL-3.0 - GPLv3
 * @link        https://easyappointments.org
 * @since       v1.6.0
 * ---------------------------------------------------------------------------- */

class Migration_Add_id_companies_to_working_plan_exceptions_table extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        if (
            $this->db->table_exists('working_plan_exceptions') &&
            !$this->db->field_exists('id_companies', 'working_plan_exceptions')
        ) {
            $this->dbforge->add_column('working_plan_exceptions', [
                'id_companies' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'null' => true,
                    'after' => 'id_users_provider',
                ],
            ]);

            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('working_plan_exceptions') .
                    '`
                    ADD CONSTRAINT `working_plan_exceptions_companies` FOREIGN KEY (`id_companies`) REFERENCES `' .
                    $this->db->dbprefix('companies') .
                    '` (`id`)
                    ON DELETE SET NULL
                    ON UPDATE CASCADE
            ',
            );
        }
    }

    /**
     * Downgrade method.
     */
    public function down(): void
    {
        if (
            $this->db->table_exists('working_plan_exceptions') &&
            $this->db->field_exists('id_companies', 'working_plan_exceptions')
        ) {
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('working_plan_exceptions') .
                    '` DROP FOREIGN KEY `working_plan_exceptions_companies`',
            );

            $this->dbforge->drop_column('working_plan_exceptions', 'id_companies');
        }
    }
}
