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

class Migration_Add_id_companies_to_appointments_table extends EA_Migration
{
    /**
     * Upgrade method.
     */
    public function up(): void
    {
        if ($this->db->table_exists('appointments') && !$this->db->field_exists('id_companies', 'appointments')) {
            $this->dbforge->add_column('appointments', [
                'id_companies' => [
                    'type' => 'BIGINT',
                    'constraint' => '20',
                    'unsigned' => true,
                    'null' => true,
                    'after' => 'id_services',
                ],
            ]);

            $this->db->query(
                '
                ALTER TABLE `' .
                    $this->db->dbprefix('appointments') .
                    '`
                    ADD CONSTRAINT `appointments_companies` FOREIGN KEY (`id_companies`) REFERENCES `' .
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
        if ($this->db->table_exists('appointments') && $this->db->field_exists('id_companies', 'appointments')) {
            $this->db->query(
                'ALTER TABLE `' .
                    $this->db->dbprefix('appointments') .
                    '` DROP FOREIGN KEY `appointments_companies`',
            );

            $this->dbforge->drop_column('appointments', 'id_companies');
        }
    }
}
