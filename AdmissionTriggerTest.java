import org.junit.jupiter.api.*;

import java.sql.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Set 3 - Hospital Bed Capacity Control
 * JDBC tests for the admission triggers (MySQL 8.0, Connector/J 8.4, JUnit 5).
 * Every test runs in its own transaction and is rolled back, so the
 * database is left exactly as test_evidence.sql left it.
 */
@TestMethodOrder(MethodOrderer.OrderAnnotation.class)
class AdmissionTriggerTest {

    private static final String URL =
            "jdbc:mysql://localhost:3306/hospital_beds"
          + "?useSSL=false&allowPublicKeyRetrieval=true&serverTimezone=Asia/Kolkata";
    private static final String USER = "hms_app";
    private static final String PASSWORD = "Hms@2026";

    private static final String ADMIT_SQL =
            "INSERT INTO admissions (patient_id, ward_id, admitting_doctor) VALUES (?, ?, ?)";

    private static final int WARD_GEN_M = 2;   // 5 of 6 beds occupied
    private static final int WARD_ISO   = 6;   // 2 of 2 beds occupied (full)

    private Connection con;

    @BeforeEach
    void open() throws SQLException {
        con = DriverManager.getConnection(URL, USER, PASSWORD);
        con.setAutoCommit(false);
        try (Statement st = con.createStatement()) {
            st.execute("SET @app_user = 'jdbc.test'");
        }
    }

    @AfterEach
    void close() throws SQLException {
        con.rollback();            // undo everything the test wrote
        con.close();
    }

    @Test @Order(1)
    void admissionToWardWithFreeBedIsAccepted() throws SQLException {
        int id;
        try (PreparedStatement ps =
                     con.prepareStatement(ADMIT_SQL, Statement.RETURN_GENERATED_KEYS)) {
            ps.setInt(1, 33);
            ps.setInt(2, WARD_GEN_M);
            ps.setString(3, "Dr. M. Kapoor");
            assertEquals(1, ps.executeUpdate());
            ResultSet keys = ps.getGeneratedKeys();
            assertTrue(keys.next());
            id = keys.getInt(1);
        }
        // the AFTER INSERT trigger must have written the audit row
        assertEquals("INSERT|jdbc.test", auditOf(id));
        assertEquals(6, occupied(WARD_GEN_M));
    }

    @Test @Order(2)
    void admissionToFullWardIsRejectedWithError5001() throws SQLException {
        int auditBefore = count("SELECT COUNT(*) FROM admission_audit");
        SQLException ex = assertThrows(SQLException.class, () -> {
            try (PreparedStatement ps = con.prepareStatement(ADMIT_SQL)) {
                ps.setInt(1, 29);
                ps.setInt(2, WARD_ISO);
                ps.setString(3, "Dr. H. Qadri");
                ps.executeUpdate();
            }
        });
        assertEquals("45000", ex.getSQLState());
        assertEquals(5001, ex.getErrorCode());
        assertTrue(ex.getMessage().startsWith("Ward ISO is full (2/2"));
        assertEquals(2, occupied(WARD_ISO));
        assertEquals(auditBefore, count("SELECT COUNT(*) FROM admission_audit"));
        System.out.println("    rejected -> SQLState " + ex.getSQLState()
                + ", error " + ex.getErrorCode() + ": " + ex.getMessage());
    }

    @Test @Order(3)
    void multiRowInsertIsAllOrNothing() throws SQLException {
        int before = count("SELECT COUNT(*) FROM admissions");
        try (Statement st = con.createStatement()) {
            SQLException ex = assertThrows(SQLException.class, () -> st.executeUpdate(
                    "INSERT INTO admissions (patient_id, ward_id, admitting_doctor) VALUES "
                  + "(33, 2, 'Dr. M. Kapoor'), (29, 6, 'Dr. H. Qadri')"));
            assertEquals(5001, ex.getErrorCode());
        }
        // row 1 (GEN-M) was valid but is gone with the failed statement
        assertEquals(before, count("SELECT COUNT(*) FROM admissions"));
        assertEquals(5, occupied(WARD_GEN_M));
    }

    @Test @Order(4)
    void jdbcBatchKeepsRowsBeforeTheFailure() throws SQLException {
        try (PreparedStatement ps = con.prepareStatement(ADMIT_SQL)) {
            ps.setInt(1, 33); ps.setInt(2, WARD_GEN_M);
            ps.setString(3, "Dr. M. Kapoor");
            ps.addBatch();
            ps.setInt(1, 29); ps.setInt(2, WARD_ISO);
            ps.setString(3, "Dr. H. Qadri");
            ps.addBatch();
            BatchUpdateException ex = assertThrows(BatchUpdateException.class, ps::executeBatch);
            int[] counts = ex.getUpdateCounts();
            assertEquals(1, counts[0]);
            assertEquals(Statement.EXECUTE_FAILED, counts[1]);
        }
        // without rewriteBatchedStatements each row is its own statement:
        // row 1 is still there until the transaction is rolled back
        assertEquals(6, occupied(WARD_GEN_M));
    }

    @Test @Order(5)
    void transferIntoFullWardIsRejectedWithError5002() {
        SQLException ex = assertThrows(SQLException.class, () -> {
            try (PreparedStatement ps = con.prepareStatement(
                    "UPDATE admissions SET ward_id = ? WHERE admission_id = ?")) {
                ps.setInt(1, WARD_ISO);
                ps.setInt(2, 1004);
                ps.executeUpdate();
            }
        });
        assertEquals(5002, ex.getErrorCode());
    }

    @Test @Order(6)
    void secondAdmissionToSameWardWaitsForTheWardLock() throws SQLException {
        // connection 1 takes the last GEN-M bed and keeps its transaction open
        try (PreparedStatement ps = con.prepareStatement(ADMIT_SQL)) {
            ps.setInt(1, 33); ps.setInt(2, WARD_GEN_M);
            ps.setString(3, "Dr. M. Kapoor");
            ps.executeUpdate();
        }
        // connection 2 must wait for the ward row locked by SELECT ... FOR UPDATE
        try (Connection con2 = DriverManager.getConnection(URL, USER, PASSWORD);
             Statement st2 = con2.createStatement()) {
            st2.execute("SET SESSION innodb_lock_wait_timeout = 2");
            SQLException ex = assertThrows(SQLException.class, () -> st2.executeUpdate(
                    "INSERT INTO admissions (patient_id, ward_id, admitting_doctor) "
                  + "VALUES (29, 2, 'Dr. P. Srinivas')"));
            assertEquals(1205, ex.getErrorCode());   // Lock wait timeout exceeded
        }
    }

    // ---------------------------------------------------------------- helpers
    private int occupied(int wardId) throws SQLException {
        return count("SELECT occupied_beds FROM vw_ward_occupancy WHERE ward_id = " + wardId);
    }

    private int count(String sql) throws SQLException {
        try (Statement st = con.createStatement(); ResultSet rs = st.executeQuery(sql)) {
            rs.next();
            return rs.getInt(1);
        }
    }

    private String auditOf(int admissionId) throws SQLException {
        try (PreparedStatement ps = con.prepareStatement(
                "SELECT action_type, changed_by FROM admission_audit WHERE admission_id = ?")) {
            ps.setInt(1, admissionId);
            ResultSet rs = ps.executeQuery();
            assertTrue(rs.next(), "no audit row");
            return rs.getString(1) + "|" + rs.getString(2);
        }
    }
}
